from dateutil import parser
import logging
from pathlib import Path
import re
import requests
from datetime import datetime
from enum import Enum
from os.path import commonprefix
from test.test_helpers import (dump_annotated_text, dump_casebook_outline,
                               dump_content_tree, dump_content_tree_children)
from urllib.parse import urlparse

import lxml.etree
import lxml.sax
from lxml import html
from django.conf import settings
from django.contrib.auth import user_logged_in
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.contrib.postgres.fields import ArrayField, JSONField
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import SearchVector, SearchVectorField, SearchQuery, SearchRank
from django.core.exceptions import ValidationError
from django.core.validators import validate_unicode_slug
from django.db import models, connection, transaction, ProgrammingError
from django.core.paginator import Paginator
from django.db.models import Count, F
from django.template.defaultfilters import truncatechars
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from django.utils.text import slugify
from pyquery import PyQuery
from pytest import raises as assert_raises
from simple_history.models import HistoricalRecords
from simple_history.utils import bulk_create_with_history, bulk_update_with_history

from .differ import AnnotationUpdater
from .sanitize import sanitize
from .utils import (block_level_elements, clone_model_instance, elements_equal,
                    get_ip_address, looks_like_case_law_link,
                    looks_like_citation, normalize_newlines,
                    parse_html_fragment, remove_empty_tags,
                    strip_trailing_block_level_whitespace, void_elements,
                    rich_text_export, prefix_ids_hrefs,
                    APICommunicationError, fix_after_rails,
                    export_via_aws_lambda)
from .storages import get_s3_storage

logger = logging.getLogger(__name__)

class User(NullableTimestampedModel, PermissionsMixin, AbstractBaseUser):
    email_address = models.CharField(max_length=255, unique=True)
    attribution = models.CharField(max_length=255, default='Anonymous', verbose_name='Display name')
    affiliation = models.CharField(max_length=255, blank=True, null=True)
    public_url = models.CharField(max_length=255, blank=True, null=True, unique=True, validators=[validate_unicode_slug, validate_unused_prefix])
    verified_professor = models.BooleanField(default=False)
    professor_verification_requested = models.BooleanField(default=False)

    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=False)

    # login-tracking fields inherited from Rails authlogic gem
    last_request_at = models.DateTimeField(blank=True, null=True,
                                           help_text="Time of last request from user (to nearest 10 minutes)")
    login_count = models.IntegerField(default=0, help_text="Number of explicit password logins by user")
    current_login_at = models.DateTimeField(blank=True, null=True, help_text="Time of most recent password login")
    last_login_at = models.DateTimeField(blank=True, null=True, help_text="Time of previous password login")
    current_login_ip = models.CharField(max_length=255, blank=True, null=True,
                                        help_text="IP of most recent password login")
    last_login_ip = models.CharField(max_length=255, blank=True, null=True, help_text="IP of previous password login")
    last_login = None  # disable the Django login tracking field from AbstractBaseUser

    EMAIL_FIELD = 'email_address'
    USERNAME_FIELD = 'email_address'
    REQUIRED_FIELDS = []  # used by createsuperuser

    objects = BaseUserManager()

    class Meta:
        indexes = [
            models.Index(fields=['affiliation']),
            models.Index(fields=['attribution']),
            models.Index(fields=['email_address']),
            models.Index(fields=['id']),
            models.Index(fields=['last_request_at']),
        ]

    @property
    def display_name(self):
        """
            In rails this is also known as "display" and "simple_display"
        """
        return self.attribution or "Anonymous"

    def __str__(self):
        return self.display_name

    def published_casebooks(self):
        return self.casebooks.filter(state=Casebook.LifeCycle.PUBLISHED.value)

    def archived_casebooks(self):
        return self.casebooks.filter(state=Casebook.LifeCycle.ARCHIVED.value)

    @property
    def directly_editable_casebooks(self):
        return (x for x in self.casebooks.exclude(state=Casebook.LifeCycle.ARCHIVED.value)
                .exclude(state=Casebook.LifeCycle.PREVIOUS_SAVE.value)
                .order_by('-updated_at').all()
                if x.directly_editable_by(self))

    @property
    def current_collaborators(self):
        return User.objects.filter(contentcollaborator__casebook__contentcollaborator__user=self)

    @property
    def follows(self):
        followed_casebooks = []
        for cb_follow in self.casebookfollow_set.order_by('created_at').prefetch_related('casebook').prefetch_related('casebook__edit_log').all():
            cb = cb_follow.casebook
            cb.new_updates = len([x for x in cb.edit_log.all() if x.entry_date >= cb_follow.updated_at])
            followed_casebooks.append(cb)
        return followed_casebooks


def update_user_login_fields(sender, request, user, **kwargs):
    """
        Register signal to record user login details on successful login, following the behavior of the Rails authlogic gem.
        To fully switch to the Django behavior (which does less user login tracking), we could rename `current_login_at`
        to `last_login`, drop the other fields, and delete this signal.
    """
    user.last_login_at = user.current_login_at
    user.current_login_at = timezone.now()
    user.last_login_ip = user.current_login_ip
    user.current_login_ip = get_ip_address(request)
    user.login_count += 1
    user.save(update_fields=['last_login_at', 'current_login_at', 'last_login_ip', 'current_login_ip', 'login_count'])


user_logged_in.connect(update_user_login_fields)


image_storage = get_s3_storage(bucket_name='h2o.images')

