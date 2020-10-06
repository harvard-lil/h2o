import logging
import os
import re
import subprocess
import tempfile
from enum import Enum
from os.path import commonprefix
from test.test_helpers import (dump_annotated_text, dump_casebook_outline,
                               dump_content_tree, dump_content_tree_children)
from urllib.parse import urlparse

import lxml.etree
import lxml.sax
from django.conf import settings
from django.contrib.auth import user_logged_in
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.contrib.postgres.fields import ArrayField, JSONField
from django.contrib.postgres.indexes import GinIndex
from django.core.exceptions import ValidationError
from django.core.validators import validate_unicode_slug
from django.db import models, transaction
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
                    get_ip_address, inner_html, normalize_newlines,
                    parse_html_fragment, remove_empty_tags,
                    strip_trailing_block_level_whitespace, void_elements)

logger = logging.getLogger(__name__)

#
# Helpers
#


class BigPkModel(models.Model):
    id = models.BigAutoField(primary_key=True)

    class Meta:
        abstract = True


class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class NullableTimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, blank=True, null=True)
    updated_at = models.DateTimeField(auto_now=True, blank=True, null=True)

    class Meta:
        abstract = True


class EditTrackedModel(models.Model):
    """
        Provide subclasses with a has_changed() function that checks whether a field name listed in tracked_fields
        has been changed since the last time the model instance was loaded or saved.

        This is the same functionality provided by django-model-utils and django-dirtyfields, but
        those packages can be error-prone in hard-to-diagnose ways, or impose a significant performance cost:

            https://www.alextomkins.com/2016/12/the-cost-of-dirtyfields/
            https://github.com/jazzband/django-model-utils/issues/331
            https://github.com/jazzband/django-model-utils/pull/313

        This class attempts to do the same thing in a minimally magical way, by requiring child classes to list the
        fields they want to track explicitly. It depends on no Django internals, except for these assumptions:

            (a) deferred fields are populated via refresh_from_db(), and
            (b) populated field values will be added to instance.__dict__
    """

    class Meta:
        abstract = True

    tracked_fields = []
    original_state = {}

    # built-in methods that need to call reset_original_state() after running:
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.reset_original_state()

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        self.reset_original_state()

    def refresh_from_db(self, *args, **kwargs):
        super().refresh_from_db(*args, **kwargs)
        self.reset_original_state()

    def reset_original_state(self):
        """
            Update original_state with the current value of each field name in tracked_fields.
            Checking k in self.__dict__ means that deferred fields will be omitted entirely,
            rather than fetched.
        """
        self.original_state = {k: getattr(self, k) for k in self.tracked_fields if k in self.__dict__}

    def has_changed(self, field_name):
        """
            Return True if the field with the given name has changed locally. Will return True for all fields of a new
            unsaved instance, and True for deferred fields whether or not they happen to match the database value.

            >>> db, assert_num_queries = [getfixture(f) for f in ['db', 'assert_num_queries']]
            >>> t = TextBlock(content="foo")
            >>> assert t.has_changed('content')             # new model: has_changed == True
            >>> t.save()
            >>> assert not t.has_changed('content')         # saved: has_changed == False
            >>> t.content = "bar"
            >>> assert t.has_changed('content')             # changing the saved value: has_changed == True
            >>> t.refresh_from_db()
            >>> assert not t.has_changed('content')         # refresh from db: has_changed == False
            >>> t2 = TextBlock.objects.get(pk=t.pk)
            >>> assert not t2.has_changed('content')        # load new copy from db: has_changed == False
            >>> t2 = TextBlock.objects.defer('content').get(pk=t.pk)
            >>> with assert_num_queries():
            ...     assert not t2.has_changed('content')    # load new copy with deferred field: has_changed == False
            >>> t2.content = "bar"
            >>> assert t2.has_changed('content')            # assign to deferred field: has_changed == True (may not be correct!)
        """
        if field_name not in self.tracked_fields:
            raise ValueError("%s is not in tracked_fields" % field_name)
        if not self.pk:
            # if model hasn't been saved yet, report all fields as changed
            return True
        if field_name not in self.__dict__:
            # if the field was deferred and hasn't been assigned to locally, report as not changed
            return False
        if field_name not in self.original_state:
            # if the field was deferred and has been assigned to locally, report as changed
            # (which won't be correct if it happens to be assigned the same value as in the db)
            return True
        return self.original_state[field_name] != getattr(self, field_name)


def cleanse_html_field(model_instance, fieldname, sanitize_field=False):
    r"""
        Munge HTML so it meets H2O's requirements.
        Models using this helper should use EditTrackedModel so model_instance.has_changed() works.

        Given:
        >>> caplog, _ = [getfixture(i) for i in ['caplog', 'db']]
        >>> html = '<p>Prepended</p><p>\n  <em>Keep foo keep baz buzz add boo</em>\n</p>'
        >>> same_after_normalizing = '<p>Prepended</p><p>\r\n  <em>Keep foo keep baz buzz add boo</em>\r\n</p>'
        >>> same_after_sanitizing = '<p>Prepended</p><p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\n</p>'
        >>> same_after_cleansing = '<p>Prepended</p>\r\n<p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\r\n</p>'
        >>> node = ContentNode(headnote=html)
        >>> node.save()

        By default, line endings are normalized and whitespace is cleaned up:
        >>> node.headnote = same_after_cleansing
        >>> with caplog.at_level(logging.DEBUG):
        ...     cleanse_html_field(node, 'headnote')
        >>> assert len(caplog.record_tuples) == 2
        >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in ContentNode headnote'
        >>> assert caplog.record_tuples[1][2] == 'Stripping trailing whitespace in ContentNode headnote'
        >>> assert node.headnote == same_after_sanitizing
        >>> caplog.clear()

        Optionally, sanitize the field to remove potentially dangerous HTML before cleaning up whitespace:
        >>> node.headnote = same_after_cleansing
        >>> with caplog.at_level(logging.DEBUG):
        ...     cleanse_html_field(node, 'headnote', True)
        >>> assert len(caplog.record_tuples) == 3
        >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in ContentNode headnote'
        >>> assert caplog.record_tuples[1][2] == 'Sanitizing ContentNode headnote'
        >>> assert caplog.record_tuples[2][2] == 'Stripping trailing whitespace in ContentNode headnote'
        >>> assert node.headnote == html
        >>> caplog.clear()

        If the field is the same after normalizing or sanitizing, stop processing:
        >>> node.headnote = same_after_normalizing
        >>> with caplog.at_level(logging.DEBUG):
        ...     cleanse_html_field(node, 'headnote', True)
        >>> assert len(caplog.record_tuples) == 1
        >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in ContentNode headnote'
        >>> caplog.clear()
        >>> node.headnote = same_after_sanitizing
        >>> with caplog.at_level(logging.DEBUG):
        ...     cleanse_html_field(node, 'headnote', True)
        >>> assert len(caplog.record_tuples) == 2
        >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in ContentNode headnote'
        >>> assert caplog.record_tuples[1][2] == 'Sanitizing ContentNode headnote'
        >>> caplog.clear()
    """

    def run_if_field_changed(func, message):
        value = getattr(model_instance, fieldname)
        if value and model_instance.has_changed(fieldname):
            logger.debug(message)
            value = func(value)
            setattr(model_instance, fieldname, value)
        return value

    run_if_field_changed(normalize_newlines,
                         "Normalizing newlines in {} {}".format(type(model_instance).__name__, fieldname))
    if sanitize_field:
        run_if_field_changed(sanitize, "Sanitizing {} {}".format(type(model_instance).__name__, fieldname))
    run_if_field_changed(strip_trailing_block_level_whitespace,
                         "Stripping trailing whitespace in {} {}".format(type(model_instance).__name__, fieldname))


class AnnotatedModel(EditTrackedModel):
    """
        Abstract base class for Case and TextBlock resource types, which can be annotated. Ensures that annotation
        offsets will be updated when the text contents of this resource are modified.
    """

    class Meta:
        abstract = True

    tracked_fields = ['content']

    def related_annotations(self):
        return ContentAnnotation.objects.valid().filter(resource__resource_id=self.id,
                                                        resource__resource_type=self.__class__.__name__)

    def save(self, *args, **kwargs):
        if self.pk and self.has_changed('content'):
            logger.debug("Updating annotations for {}".format(type(self).__name__))
            ContentAnnotation.update_annotations(self.related_annotations(), self.original_state['content'],
                                                 self.content)
        super().save(*args, **kwargs)


#
# Models
#

class Case(NullableTimestampedModel, AnnotatedModel):
    name_abbreviation = models.CharField(max_length=150)
    name = models.CharField(max_length=10000, blank=True, null=True)
    decision_date = models.DateField(blank=True, null=True)
    public = models.BooleanField(default=False, blank=True, null=True)
    created_via_import = models.BooleanField(default=False)
    capapi_id = models.IntegerField(blank=True, null=True)
    attorneys = JSONField(blank=True, null=True)
    parties = JSONField(blank=True, null=True)
    opinions = JSONField(blank=True, null=True)
    citations = JSONField(blank=True, null=True)
    docket_number = models.CharField(max_length=20000, blank=True, null=True)
    header_html = models.CharField(max_length=15360, blank=True, null=True)
    content = models.CharField(max_length=5242880)
    court_name = models.CharField(max_length=1024, blank=True, null=True)
    history = HistoricalRecords()

    class Meta:
        indexes = [
            GinIndex(fields=['citations']),
            models.Index(fields=['created_at']),
            models.Index(fields=['decision_date']),
            models.Index(fields=['name_abbreviation']),
            models.Index(fields=['public']),
            models.Index(fields=['updated_at'])
        ]

    def save(self, *args, **kwargs):
        r"""
            Override save to ensure Case HTML is cleansed and annotations are
            repositioned on save.

            Given:
            >>> annotations_factory, caplog = [getfixture(f) for f in ['annotations_factory', 'caplog']]
            >>> html_with_annotations =     '<p>\n  <em>[note]Keep foo[/note] [highlight]delete bar[/highlight] [elide]keep baz[/elide] buzz</em>\n</p><p>bam</p>'
            >>> new_html =                  '<p>Prepended</p>\n\n<p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\n</p>'
            >>> new_case_html_with_annotations = '<p>Prepended</p><p>\n  <em invalid-attr="invalid">[note]Keep foo[/note] <invalid>[elide]keep baz</invalid>[/elide] buzz add boo</em>\n</p>'

            On save, Case HTML is cleansed (but not sanitized), and then annotations are updated:
            >>> _, case = annotations_factory('Case', html_with_annotations)
            >>> case.resource.content = new_html
            >>> with caplog.at_level(logging.DEBUG):
            ...     case.resource.save()
            >>> assert dump_annotated_text(case) == new_case_html_with_annotations
            >>> assert len(caplog.record_tuples) == 3
            >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in Case content'
            >>> assert caplog.record_tuples[1][2] == 'Stripping trailing whitespace in Case content'
            >>> assert caplog.record_tuples[2][2] == 'Updating annotations for Case'
        """
        cleanse_html_field(self, 'content')
        super().save(*args, **kwargs)

    def get_name(self):
        return self.name_abbreviation if self.name_abbreviation else self.name

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Case')

    @property
    def prefer_meta_header(self):
        """
        When we think that a case has come from CAP, we try to show the verified metadata (name, citations, decision date, court) that has been cleaned.
        """
        return self.created_via_import

    @property
    def cite_string(self):
        return ", ".join([x['cite'] for x in self.citations if 'cite' in x])


class ContentAnnotationQueryset(models.QuerySet):
    def valid(self):
        """
            Return annotations excluding those that were marked invalid when shifting.
        """
        return self.exclude(global_start_offset=-1, global_end_offset=-1)


class ContentAnnotation(TimestampedModel, BigPkModel):
    kind = models.CharField(max_length=255, choices=(
    ('replace', 'replace'), ('highlight', 'highlight'), ('elide', 'elide'), ('note', 'note'), ('link', 'link')))
    content = models.TextField(blank=True, null=True)
    global_start_offset = models.IntegerField(blank=True, null=True)
    global_end_offset = models.IntegerField(blank=True, null=True)

    resource = models.ForeignKey(
        'ContentNode',
        on_delete=models.CASCADE,
        related_name='annotations',
    )

    objects = ContentAnnotationQueryset.as_manager()

    # legacy fields, from an era when annotation offsets were paragraph-based, rather than document-based
    # https://github.com/harvard-lil/h2o/issues/1044
    start_paragraph = models.IntegerField(blank=True, null=True)
    end_paragraph = models.IntegerField(blank=True, null=True)
    start_offset = models.IntegerField(blank=True, null=True)
    end_offset = models.IntegerField(blank=True, null=True)
    history = HistoricalRecords()

    class Meta:
        indexes = [
            models.Index(fields=['resource', 'start_paragraph'])
        ]
        # annotations return in document order, with id to ensure sort stability
        ordering = ['global_start_offset', 'id']

    def __str__(self):
        return "%s %s-%s%s" % (self.kind, self.global_start_offset, self.global_end_offset,
                               " with %s" % truncatechars(self.content, 20) if self.content else "")

    @staticmethod
    def text_from_html(html):
        r"""
            Return all text, including spaces, from the html, using the LXML library.
            >>> html = ' \n <p> \r\n <em> foo </em> \n </p> \n <p> \n <em> foo </em> \n </p> \n '
            >>> assert ContentAnnotation.text_from_html(html) == ' \n  \r\n  foo  \n  \n  \n  foo  \n  \n '
            >>> assert ContentAnnotation.text_from_html(' foo ') == ' foo '
            >>> assert ContentAnnotation.text_from_html(' foo <p> bar </p> baz ') == ' foo  bar  baz '
        """
        return parse_html_fragment(html).text_content()

    @classmethod
    def update_annotations(cls, queryset, before_html, after_html):
        r"""
            Update annotation global_start_offset and global_end_offset for all annotations in the given queryset,
            based on the changes from before_html to after_html. NOTE: This assumes that the html has a single root
            element, and that annotation offsets are relative to the text within that element.

            See AnnotatedModel for tests.
        """
        before = cls.text_from_html(before_html)
        after = cls.text_from_html(after_html)
        if before == after:
            # text may be the same even if html is different
            return
        updater = AnnotationUpdater(before, after)
        to_update = []

        # process all annotations after first edited text
        annotation_query = queryset.filter(global_end_offset__gte=updater.get_first_delta_offset())
        for annotation in annotation_query:

            # get new annotation location
            new_start = updater.adjust_offset(annotation.global_start_offset)
            new_end = updater.adjust_offset(annotation.global_end_offset)

            # skip unchanged annotations
            if new_start == annotation.global_start_offset and new_end == annotation.global_end_offset:
                continue

            # handle deleted annotations
            if new_start == new_end:
                new_start = new_end = -1

            # apply changes
            annotation.global_start_offset = new_start
            annotation.global_end_offset = new_end
            to_update.append(annotation)

        # save all changes
        if to_update:
            bulk_update_with_history(to_update, ContentAnnotation, ['global_start_offset', 'global_end_offset'], batch_size=500, default_change_reason="Automated Shift")

class TempCollaborator(TimestampedModel, BigPkModel):
    has_attribution = models.BooleanField(default=False)
    can_edit = models.BooleanField(default=False)
    user = models.ForeignKey('User',
                             on_delete=models.CASCADE,
                             )
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete unneeded ContentCollaborator rows in the Casebook.delete method.
    casebook = models.ForeignKey(
        'Casebook',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True
    )

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

    class Meta:
        unique_together = (('user', 'casebook'),)


class ContentCollaborator(TimestampedModel, BigPkModel):
    has_attribution = models.BooleanField(default=False)
    can_edit = models.BooleanField(default=False)
    user = models.ForeignKey('User',
                             on_delete=models.CASCADE,
                             )
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete unneeded ContentCollaborator rows in the Casebook.delete method.
    content = models.ForeignKey(
        'ContentNode',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True
    )

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

    class Meta:
        unique_together = (('user', 'content'),)


class ContentNodeQueryset(models.QuerySet):
    """
        This queryset allows us to do ContentNode.objects.prefetch_resources() so that fetched content nodes will
        efficiently have their content_node.resource attribute pre-populated, using a total of three queries instead
        of one query per instance. This is based on the implementation of prefetch_related().

        Given:
        >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]
        >>> section = ContentNode.objects.filter(new_casebook=full_casebook).first()

        Fetching all resources normally will take a linear number of queries -- each c.resource hits the DB:
    """

    # keep track of input values from prefetch_resources()
    _prefetch_resources_done = False
    _prefetch_resources = None

    def prefetch_resources(self, case_query=None, textblock_query=None, link_query=None):
        """
            Return cloned queryset with attributes to trigger prefetching in _fetch_all.
        """
        clone = self._chain()
        clone._prefetch_resources = [case_query, textblock_query, link_query]
        return clone

    def _clone(self):
        """
            Ensure that prefetch_resources() attributes survive cloning.
        """
        c = super()._clone()
        c._prefetch_resources = self._prefetch_resources
        return c

    def _fetch_all(self):
        """
            Do the actual work: get IDs for all items in _result_cache, prefetch related Case/TextBlock/Link objects,
            and store them in each item's _resource attribute.
        """
        super()._fetch_all()
        if self._prefetch_resources and not self._prefetch_resources_done:
            self._prefetch_resources_done = True
            if not self._result_cache:
                return
            case_query, textblock_query, link_query = self._prefetch_resources
            if case_query is None:
                case_query = Case.objects.all()
            if textblock_query is None:
                textblock_query = TextBlock.objects.all()
            if link_query is None:
                link_query = Link.objects.all()
            resources = {}
            for resource_type, query in (('Case', case_query), ('TextBlock', textblock_query), ('Link', link_query)):
                for obj in query.filter(
                        id__in=[obj.resource_id for obj in self._result_cache if obj.resource_type == resource_type]):
                    resources[(resource_type, obj.id)] = obj
            for content_node in self._result_cache:
                if content_node.resource_id:
                    content_node._resource = resources.get((content_node.resource_type, content_node.resource_id))
                    content_node._resource_prefetched = True

class MaterializedPathTreeMixin(models.Model):
    class Meta:
        abstract = True
    ordinals = ArrayField(models.IntegerField(), default=list)

    ##
    # Content tree methods
    ##

    ## content tree: public methods
    # (these can be called without calling content_tree__load first, and are intended for manipulating the tree from outside)

    def content_tree__get_next_available_child_ordinals(self):
        """
            If we add a new section or resource as a child to this node,
            what should that node's ordinals be?
        """
        self.content_tree__load()
        prefix = self.ordinals if self.ordinals else []
        return prefix + [max([x.ordinals[-1] for x in self.content_tree__children] or [0]) + 1]

    def content_tree__move_to(self, new_ordinals):
        """
            Move this node to a new place in the content tree. This is the main entrypoint for content tree work; the
            other functions mostly just enable this one.

            NOTE: new_ordinals is the path to the new location *before* removing the node from its current location.
            (See the "Move into a parent whose ordinal will change because of the move" test below, where new_ordinals
            is [1, 5, 2] instead of [1, 4, 2].)

            Given:
            >>> assert_num_queries = getfixture('assert_num_queries')
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')

            Move a node from one place to another:
            >>> with assert_num_queries(select=2, update=1, insert=1):
            ...     r_1_4_1.content_tree__move_to([2, 1])
            >>> assert dump_content_tree(casebook) == [
            ...         [s_1, casebook, [
            ...             [r_1_1, s_1, []],
            ...             [r_1_2, s_1, []],
            ...             [r_1_3, s_1, []],
            ...             [s_1_4, s_1, [
            ...                 [r_1_4_2, s_1_4, []],
            ...                 [r_1_4_3, s_1_4, []],
            ...             ]],
            ...         ]],
            ...         [s_2, casebook, [
            ...             [r_1_4_1, s_2, []],
            ...         ]],
            ...     ]

            Move node forward within the same level:
            >>> casebook.refresh_from_db()
            >>> s_1_4.refresh_from_db()
            >>> r_1_4_2.refresh_from_db()
            >>> r_1_4_2.content_tree__move_to([1, 4, 2])
            >>> assert dump_content_tree_children(s_1_4) == [r_1_4_3, r_1_4_2]

            Move node backward within the same level:
            >>> r_1_4_2.refresh_from_db()
            >>> r_1_4_2.content_tree__move_to([1, 4, 1])
            >>> assert dump_content_tree_children(s_1_4) == [r_1_4_2, r_1_4_3]

            Become a parent of self:
            >>> r_1_4_2.refresh_from_db()
            >>> r_1_4_2.content_tree__move_to([1, 4])
            >>> assert dump_content_tree(s_1) == [
            ...     [r_1_1, s_1, []],
            ...     [r_1_2, s_1, []],
            ...     [r_1_3, s_1, []],
            ...     [r_1_4_2, s_1, []],
            ...     [s_1_4, s_1, [
            ...         [r_1_4_3, s_1_4, []],
            ...     ]],
            ... ]

            Move into a parent whose ordinal will change because of the move:
            >>> r_1_4_2.refresh_from_db()
            >>> r_1_4_2.content_tree__move_to([1, 5, 2])
            >>> assert dump_content_tree_children(s_1_4) == [r_1_4_3, r_1_4_2]
            >>> assert r_1_4_2.ordinals == [1, 4, 2]  # note that this is, correctly, different from the value provided, because parent moved

            Enforce some rules:
            >>> with assert_raises(ValueError, match='Cannot move casebook node'):
            ...     casebook.content_tree__move_to([2])
            >>> with assert_raises(ValueError, match='Cannot move node to root'):
            ...     s_1.content_tree__move_to([])
            >>> with assert_raises(ValueError, match='Cannot add descendant of Resource'):
            ...     r_1_4_2.content_tree__move_to([1, 1, 1])
            >>> with assert_raises(ValueError, match='Cannot move a node inside itself'):
            ...     s_1.content_tree__move_to([1, 1, 1])
        """
        # check rules
        if new_ordinals == self.ordinals:
            return
        if len(new_ordinals) < 1:
            raise ValueError("Cannot move node to root")
        if type(self) is Casebook:
            raise ValueError("Cannot move casebook node")
        if new_ordinals[:len(self.ordinals)] == self.ordinals:
            raise ValueError("Cannot move a node inside itself")

        # find common grandparent node for old and new location
        old_ordinals = self.ordinals
        common_prefix = commonprefix((old_ordinals, new_ordinals[:-1]))
        common_parent_node = self.content_tree__get_same_tree_node_from_ordinals(common_prefix)
        common_parent_node.content_tree__load()

        # find new parent
        # (do this before the move so the ordinal for the parent hasn't changed)
        try:
            new_parent = common_parent_node.content_tree__get_descendant(new_ordinals[:-1])
        except IndexError:
            raise ValueError("Invalid new ordinals; parent does not exist: %s" % new_ordinals)
        if new_parent.is_resource:
            raise ValueError('Cannot add descendant of Resource')

        # remove node from existing location
        # (look up the location, instead of using self, so we have the copy where content_tree is populated)
        moved_node = common_parent_node.content_tree__get_descendant(old_ordinals)
        if moved_node != self:
            raise ValueError("Unexpected element found at ordinal {}: {}".format(old_ordinals, moved_node))
        moved_node.content_tree__parent.content_tree__children.remove(moved_node)

        # add node to new location
        new_parent.content_tree__children.insert(new_ordinals[-1] - 1, moved_node)

        # save results
        common_parent_node.content_tree__store()
        self.ordinals = moved_node.ordinals

    def content_tree__repair(self):
        """
            For more complete tests, see Section.delete and Resource.delete

            >>> assert_num_queries, casebook = [getfixture(f) for f in ['assert_num_queries', 'full_casebook']]

            >>> with assert_num_queries(select=1):
            ...     casebook.content_tree__repair()
        """
        self.content_tree__load()
        self.content_tree__store()

    ## content tree: pre-fetching
    # For query efficiency, content trees must be prefetched by content_tree__load() before most methods will work.
    # Prefetched data is stored in the following variables. The @properties test that content_tree__load() has been called.

    CONTENT_TREE_NOT_LOADED = object()
    _content_tree__parent = CONTENT_TREE_NOT_LOADED
    _content_tree__children = CONTENT_TREE_NOT_LOADED

    @property
    def content_tree__parent(self):
        if self._content_tree__parent is self.CONTENT_TREE_NOT_LOADED:
            raise ValueError("Cannot use content_tree.parent before calling content_tree.load on parent node.")
        return self._content_tree__parent

    @property
    def content_tree__children(self):
        if self._content_tree__children is self.CONTENT_TREE_NOT_LOADED:
            raise ValueError("Cannot use content_tree.children before calling content_tree.load.")
        return self._content_tree__children

    @property
    def children(self):
        return self._content_tree__children

    def content_tree__load(self):
        """
            Fetch all descendants of this node and populate their content_tree__parent and content_tree__children
            values. The one value that will *not* work after this call is self.content_tree__parent; only the sub-tree is fetched.

            Given:
            >>> assert_num_queries, casebook_sections_factory = [getfixture(i) for i in ['assert_num_queries', 'casebook_sections_factory']]
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')

            Can prefetch a single section:
            >>> with assert_num_queries(select=1):
            ...     assert dump_content_tree(s_1_4) == [
            ...         [r_1_4_1, s_1_4, []],
            ...         [r_1_4_2, s_1_4, []],
            ...         [r_1_4_3, s_1_4, []],
            ...     ]

            Can prefetch an entire casebook:
            >>> with assert_num_queries(select=1):
            ...     assert dump_content_tree(casebook) == [
            ...         [s_1, casebook, [
            ...             [r_1_1, s_1, []],
            ...             [r_1_2, s_1, []],
            ...             [r_1_3, s_1, []],
            ...             [s_1_4, s_1, [
            ...                 [r_1_4_1, s_1_4, []],
            ...                 [r_1_4_2, s_1_4, []],
            ...                 [r_1_4_3, s_1_4, []],
            ...             ]],
            ...         ]],
            ...         [s_2, casebook, []],
            ...     ]

            Real-life test case that revealed an error in the "elif parent:" logic:
            >>> casebook, ords = casebook_sections_factory((1,), (1, 1), (1, 1, 1), (1, 2), (1, 2, 1), (1, 3), (1, 3, 1), (2,))
            >>> assert dump_content_tree(casebook) == [
            ...     [ords[(1,)], casebook, [
            ...         [ords[(1, 1)], ords[(1,)], [
            ...             [ords[(1, 1, 1)], ords[(1, 1)], []]]],
            ...         [ords[(1, 2)], ords[(1,)], [
            ...             [ords[(1, 2, 1)], ords[(1, 2)], []]]],
            ...         [ords[(1, 3)], ords[(1,)], [
            ...             [ords[(1, 3, 1)], ords[(1, 3)], []]]]]],
            ...     [ords[(2,)], casebook, []]]
        """
        parents = []
        parent = last_child = None
        for node in [self] + list(self.sub_sections.all()):
            if last_child and node.content_tree__is_descendant_of(last_child):
                parents.append(parent)
                parent = last_child
            elif parent:
                while not node.content_tree__is_descendant_of(parent):
                    parent = parents.pop()
            node._content_tree__parent = parent
            node._content_tree__children = []
            if parent:
                parent._content_tree__children.append(node)
            last_child = node

    @property
    def content_tree__descendants(self):
        for child in self.children:
            yield child
            for grandchild in child.children:
                yield grandchild

    ## content tree: storing updates

    def content_tree__store(self):
        """
            Update ordinals in the database for any that need to change, based on nodes that have been moved within
            content_tree__children. It is not valid to add nodes from outside, as their tree values will not be populated.

            [self] is included because we don't know whether self.ordinals has changed or not.
        """
        to_update = [self] + list(self.content_tree__update_ordinals())
        bulk_update_with_history(to_update, ContentNode, ['ordinals'], batch_size=500, default_change_reason="Tree Repair")


    def content_tree__update_ordinals(self):
        """
            Recursively fix ordinals for all descendants that have been moved in the content tree, based on their
            current position in content_tree__children. Return an iterator of all descendants that have been updated.

            Given:
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
            >>> casebook.content_tree__load()
            >>> s_1 = casebook.content_tree__get_descendant([1])
            >>> s_2 = casebook.content_tree__get_descendant([2])

            When we move a node, return only nodes with changed ordinals:
            >>> s_2.content_tree__children.insert(0, s_1.content_tree__children.pop(2))  # move r_1_3 from s_1 to beginning of s_2
            >>> assert set(casebook.content_tree__update_ordinals()) == {r_1_3, s_1_4, r_1_4_2, r_1_4_3, r_1_4_1}
        """
        for i, node in enumerate(self.content_tree__children):
            correct_ordinals = self.ordinals + [i + 1]
            if node.ordinals != correct_ordinals:
                node.ordinals = correct_ordinals
                yield node
            if node.content_tree__children:
                yield from node.content_tree__update_ordinals()

    ## content tree: helper functions

    def content_tree__is_descendant_of(self, parent):
        """
            True if ordinals make self a content_tree descendant of parent.
            (This assumes we already know that the nodes are part of the same tree.)
            >>> assert Section(ordinals=[1,1]).content_tree__is_descendant_of(Section(ordinals=[1]))
            >>> assert Resource(ordinals=[1,2,3]).content_tree__is_descendant_of(Section(ordinals=[1]))
        """
        return False if type(self) is Casebook else self.ordinals[:len(parent.ordinals)] == parent.ordinals

    def content_tree__get_same_tree_node_from_ordinals(self, ordinals):
        """ Fetch a node from the database, with the given ordinals, that is part of the same tree as self. """
        casebook_id = self.id if type(self) == Casebook else self.new_casebook_id
        return ContentNode.objects.get(ordinals=ordinals,
                                       new_casebook_id=casebook_id) if ordinals else Casebook.objects.get(id=casebook_id)

    def content_tree__get_descendant(self, ordinals):
        """
            Fetch a node from content_tree__children with the given ordinals.
        """
        if ordinals[:len(self.ordinals)] != self.ordinals:
            raise ValueError("Ordinal value is not a descendant of self")
        node = self
        ordinals = ordinals[len(self.ordinals):]
        while ordinals:
            node = node.content_tree__children[ordinals.pop(0) - 1]
        return node


    ###
    #  Display helpers
    ###

    def ordinal_string(self):
        """
        A human-friendly rendering of the "ordinals" field.
        Might be more appropriate as a templatetag.
        """
        return '.'.join(str(o) for o in self.ordinals)

    def ordinals_with_urls(self, editing=False):
        """
        A helper method for assembling Sections' and Resources' breadcrumb links.
        Might be more appropriate as a templatetag.
        """
        return_value = []
        ordinals = []
        for o in self.ordinals:
            ordinals.append(o)
            return_value.append({
                'ordinal': o,
                'ordinals': [*ordinals],
                'url': ContentNode.objects.get(
                    new_casebook_id=self.new_casebook_id,
                    ordinals=ordinals
                ).get_edit_or_absolute_url(editing)
            })
        return return_value


class TrackedCloneable(models.Model):
    class Meta:
        abstract = True

    provenance = ArrayField(models.BigIntegerField(), default=list, blank=False)

    ##
    # Version tree methods
    ##

    def version_tree__descendants(self):
        """
            Return all descendants of this node.
            (Used to track the provenance of casebooks; not used to describe the
            contents of a given casebook.)

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('casebook_tree')
            >>> assert set(root.version_tree__descendants()) == {c_1, c_2, c_1_1, c_1_2}
            >>> assert set(c_1.version_tree__descendants()) == {c_1_1, c_1_2}
            >>> assert set(c_2.version_tree__descendants()) == set()
        """
        return type(self).objects.filter(provenance__contains=[self.id])

    def version_tree__root(self):
        """
            Return root node for this node, or None if no ancestors.
            (Used to track the provenance of casebooks; not used to describe the
            contents of a given casebook.)

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('casebook_tree')
            >>> assert root.version_tree__root() is None
            >>> assert c_1.version_tree__root() == root
            >>> assert c_1_1.version_tree__root() == root
        """
        if not self.provenance:
            return None
        return type(self).objects.filter(id=self.provenance[0]).get().new_casebook

    def version_tree__parent(self):
        """
            Return parent node for this node, or None if no ancestors.
            (Used to track the provenance of casebooks; not used to describe the
            contents of a given casebook.)

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('casebook_tree')
            >>> assert root.version_tree__parent() is None
            >>> assert c_1.version_tree__parent() == root
            >>> assert c_1_1.version_tree__parent() == c_1
            >>> assert c_2.version_tree__parent() == root
        """
        if not self.provenance:
            return None
        return type(self).objects.get(pk=self.provenance[-1])


class ContentNode(EditTrackedModel, TimestampedModel, BigPkModel, MaterializedPathTreeMixin, TrackedCloneable):
    title = models.CharField(max_length=10000, default="Untitled")
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)
    # legacy field: https://github.com/harvard-lil/h2o/issues/1044
    raw_headnote = models.TextField(blank=True, null=True)
    copy_of = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='clones',
    )
    history = HistoricalRecords()

    # Some fields are only used by certain subsets of ContentNodes
    # https://github.com/harvard-lil/h2o/issues/1035

    # casebooks only
    public = models.BooleanField(default=False)
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True,
                                                           help_text='Unknown (None) or True; never False')
    collaborators = models.ManyToManyField('User',
                                           through='ContentCollaborator',
                                           related_name='old_casebooks'
                                           )

    # sections and resources only
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete Casebook contents in the Casebook.delete method.
    casebook = models.ForeignKey(
        'ContentNode',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name='old_casebook_contents'
    )

    new_casebook = models.ForeignKey(
        'Casebook',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name='contents'
    )
    # resources only
    # These fields define a relationship with a Case, Link, or Textblock
    # not yet described/available via the Django ORM
    # https://github.com/harvard-lil/h2o/issues/1035
    resource_type = models.CharField(max_length=255, blank=True, null=True)
    resource_id = models.BigIntegerField(blank=True, null=True)

    objects = ContentNodeQueryset.as_manager()
    tracked_fields = ['headnote']

    class Meta:
        indexes = [
            models.Index(fields=['casebook', 'ordinals']),
            models.Index(fields=['resource_type', 'resource_id'])
        ]
        ordering = ['ordinals']

    @classmethod
    def from_db(cls, db, field_names, values):
        """
            Return Casebooks, Sections, and Resources instead of ContentNodes,
            for more intuitive resolution of relationships and for tidiness.
            Directly contradicts the docs:
            https://docs.djangoproject.com/en/2.2/topics/db/models/#querysets-still-return-the-model-that-was-requested

            Given:
            >>> casebook, section, resource_factory, case_factory = [getfixture(i) for i in ['casebook', 'section', 'resource_factory', 'case_factory']]
            >>> resource = resource_factory(new_casebook=casebook, resource_type='Case', resource_id=case_factory().id)

            ContentNode queries return the appropriate proxy models:
        """
        values_dict = dict(zip(field_names, values))
        if not values_dict['casebook_id']:
            # subclass = Casebook
            subclass = ContentNode
        elif not values_dict['resource_id']:
            subclass = Section
        else:
            subclass = Resource
        return models.Model.from_db.__func__(subclass, db, field_names, values)

    def as_proxy(self):
        if not self.resource_type or self.resource_type == 'Section':
            self.__class__ = Section
        else:
            self.__class__ = Resource
        return self

    _resource_prefetched = False
    _resource = None

    @property
    def resource(self):
        """
        Resource nodes are each related to one Case, TextBlock, or Link object,
        which has historically been referred to as the node's "resource."

        (Resource objects might more accurately be called "ResourceWrapper"
        objects, or similar.)

        This method retrieves the node's related resource, in the manner one
        would expect to be able to do if this relationship were achieved via
        foreign keys (not possible on the Django side, without altering the
        database so as to support generic foreign keys or polymorphic models).
        """
        if hasattr(self,'_resource_prefetched') and not self._resource_prefetched:
            if not self.resource_id:
                return None
            if self.resource_type in ['Case', 'TextBlock', 'Link']:
                # so fancy...
                self._resource = globals()[self.resource_type].objects.get(id=self.resource_id)
                self._resource_prefetched = True
            else:
                raise NotImplementedError
        return self._resource

    @property
    def contents(self):
        """
        See https://github.com/harvard-lil/h2o/blob/master/app/models/content/concerns/has_children.rb#L5
        """
        # Django syntax for inspecting a slice of an array field
        # https://docs.djangoproject.com/en/2.2/ref/contrib/postgres/fields/#slice-transforms
        # We want only nodes whose first ordinals match this section's.
        # That is, if this is section [2, 2], we want [2, 2, 1], [2, 2, 2, 7], etc.,
        # but not [2, 1, 1], [1,1], etc.
        first_ordinals = "ordinals__0_{}".format(len(self.ordinals))
        filter_map = {
            "new_casebook_id": self.new_casebook_id,
            first_ordinals: self.ordinals
        }
        res = ContentNode.objects.filter(**filter_map).exclude(id=self.id)
        return res


    @property
    def is_temporary(self):
        return self.resource_type == 'Temp'

    @property
    def can_publish(self):
        return self.new_casebook.can_publish

    @property
    def has_body(self):
        return bool(self.resource_type and self.resource_type != 'Temp' and self.resource_type != 'Section')

    @property
    def body(self):
        return (self._resource or self.resource) if self.has_body else None

    @property
    def body_template(self):
        if not self.has_body:
            return 'includes/bodies/empty.html'
        return {'Case': 'includes/bodies/case.html', 'Link': 'includes/bodies/link.html', 'TextBlock': 'includes/bodies/text_block.html'}[self.resource_type]

    def save(self, *args, **kwargs):
        r"""
            Override save to include the cleanup of user-supplied HTML.

            Given:
            >>> caplog, _ = [getfixture(i) for i in ['caplog', 'db']]
            >>> html = '<p>Prepended</p>\n\n<p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\n</p>'
            >>> cleaned_html = '<p>Prepended</p><p>\n  <em>Keep foo keep baz buzz add boo</em>\n</p>'

            On save, the headnote is cleansed.
            >>> node = ContentNode(headnote=html)
            >>> with caplog.at_level(logging.DEBUG):
            ...     node.headnote = html
            ...     node.save()
            >>> node.refresh_from_db()
            >>> assert node.headnote == cleaned_html
        """
        cleanse_html_field(self, 'headnote', True)
        super().save(*args, **kwargs)

    ##
    # Methods common to all ContentNodes
    ##

    def get_slug(self):
        return slugify(self.title)

    def viewable_by(self, user):
        return self.new_casebook.viewable_by(user)

    def directly_editable_by(self, user):
        """
        Allow a user to make real-time changes (e.g., via edit view),
        rather than requiring them to make changes via the draft mechanism.
        (See allows_draft_creation_by for more discussion of editing and drafts.)
        """
        return self.new_casebook.is_private and self.new_casebook.editable_by(user)

    def __str__(self):
        return "{} ({})".format(self.title, self.id)

    @property
    def is_resource(self):
        return self.resource_id is not None


    @property
    def sub_sections(self):
        """
        See https://github.com/harvard-lil/h2o/blob/master/app/models/content/concerns/has_children.rb#L5
        """
        # Django syntax for inspecting a slice of an array field
        # https://docs.djangoproject.com/en/2.2/ref/contrib/postgres/fields/#slice-transforms
        # We want only nodes whose first ordinals match this section's.
        # That is, if this is section [2, 2], we want [2, 2, 1], [2, 2, 2, 7], etc.,
        # but not [2, 1, 1], [1,1], etc.
        first_ordinals = "ordinals__0_{}".format(len(self.ordinals))
        filter_map = {
            "new_casebook_id": self.new_casebook_id,
            first_ordinals: self.ordinals
        }
        return ContentNode.objects.filter(**filter_map).exclude(id=self.id)

    @property
    def annotatable(self):
        """
        Only particular kinds of resources can be annotated.
        """
        return self.type == 'resource' and self.resource_type in ['Case', 'TextBlock']

    def get_annotate_url(self):
        """
        If a resource can be annotated, returns the URL for the page an author
        uses to make annotations. Otherwise, returns a ValueError.
        """
        if self.annotatable:
            return reverse('annotate_resource', args=[self.new_casebook, self])
        raise ValueError('Only Resources (Case and TextBlock) can be annotated.')

    @property
    def get_preferred_url(self):
        """
        When this resource is displayed for the given user, this method provides the
        default/preferred url.
        User does not have edit permissions or resource not editable?
         - Return the read url for this resource/section
        User has edit permission?
         Section:
          - Return the layout url.
          Case/Text:
          - Return the annotate url.
          Link/Temp:
          - Return the edit url.
        """
        if not (self.in_edit_state):
            return self.get_absolute_url()
        elif self.annotatable:
            return self.get_annotate_url()
        return self.get_edit_url()

    @property
    def type(self):
        # TODO: In use in templates and tests; shouldn't be necessary. Consider refactoring.
        if not self.resource_type or self.resource_type == 'Section':
            return 'section'
        elif self.resource_type == 'Temp':
            return 'temp'
        else:
            return 'resource'

    def export(self, include_annotations, file_type='docx'):
        """
            Export this node and children as docx, or as html for conversion by pandoc.

            Given:
            >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

            Export uses 5 queries: selecting descendant nodes, and prefetching ContentAnnotation, Case, TextBlock, and Link.
            >>> with assert_num_queries(select=5):
            ...     file_data = full_casebook.export(include_annotations=True)
        """
        # prefetch all child nodes and related data
        children = list(self.contents.prefetch_resources().prefetch_related('annotations')) if type(
            self) is not Resource else None

        # render html
        if not self.resource_type or self.resource_type == 'Section':
            template_name = 'export/section.html'
        elif self.resource_type == 'Temp':
            template_name = 'export/tbd.html'
        else:
            template_name = 'export/node.html'
        html = render_to_string(template_name, {
            'is_export': True,
            'node': self,
            'children': children,
            'include_annotations': include_annotations,
        })
        if file_type == 'html':
            return html

        # convert to docx with pandoc
        with tempfile.NamedTemporaryFile(suffix='.docx') as pandoc_out:
            command = [
                'pandoc',
                '--from', 'html',
                '--to', 'docx',
                '--reference-doc', os.path.join(settings.PANDOC_DIR, 'reference.docx'),
                '--output', pandoc_out.name,
                '--quiet'
            ]
            if type(self) is Casebook:
                command.extend(['--lua-filter', os.path.join(settings.PANDOC_DIR, 'table_of_contents.lua')])
            try:
                response = subprocess.run(command, input=html.encode('utf8'), stderr=subprocess.PIPE,
                                          stdout=subprocess.PIPE)
            except subprocess.CalledProcessError as e:
                raise Exception("Pandoc command failed: %s" % e.stderr[:100])
            if response.stderr:
                raise Exception("Pandoc reported error: %s" % response.stderr[:100])
            return pandoc_out.read()

    def headnote_for_export(self):
        r"""
            Return headnote HTML prepared for pandoc export.

            >>> assert Resource(headnote='<p>An image <img src=""></p>').headnote_for_export() == '<p>An image </p>'
        """
        if not self.headnote:
            return ''
        tree = parse_html_fragment(self.headnote)
        PyQuery(tree).remove('img')
        return mark_safe(inner_html(tree))

    @staticmethod
    def update_tree_for_export(tree):
        """
            Prepare an lxml tree (annotated or un-annotated) for export.
        """
        tree = PyQuery(tree)

        # remove images
        tree.remove('img')

        # Case Header styling
        for pq in tree('section.head-matter p, center, p[style="text-align:center"], p[align="center"]').items():
            pq.wrap("<div data-custom-style='Case Header'></div>")
        for el in tree('section.head-matter h4, center h2, h2[style="text-align:center"], h2[align="center"]'):
            el.tag = 'div'
            el.attrib['data-custom-style'] = 'Case Header'

        return tree

    def content_for_export(self):
        r"""
            Return content as html for export to Pandoc, without annotations.

            >>> resource, *_ = [getfixture(f) for f in ['resource']]
            >>> resource.resource.content = '<center>Title</center><h2 align="center">Subtitle</h2><p>An image <img src=""></p>'
            >>> output = '<div data-custom-style="Case Header"><center>Title</center></div><div align="center" data-custom-style="Case Header">Subtitle</div><p>An image </p>'
            >>> assert resource.content_for_export() == output
        """
        tree = parse_html_fragment(self.resource.content)
        self.update_tree_for_export(tree)
        return mark_safe(inner_html(tree))

    def annotated_content_for_export(self):
        r"""
            Return content as html for export to Pandoc, with annotations.

            Given:
            >>> annotations_factory, *_ = [getfixture(f) for f in ['annotations_factory']]
            >>> def assert_match(source_html, expected_html):
            ...     annotated_html = annotations_factory('Case', source_html)[1].annotated_content_for_export()
            ...     assert elements_equal(
            ...         parse_html_fragment(annotated_html),
            ...         parse_html_fragment(expected_html),
            ...         ignore_trailing_whitespace=True
            ...     ), "Expected:\n%s\nGot:\n%s" % (expected_html, annotated_html)

            Basic format of all annotations:
            >>> input = '''<p>
            ...     [note my note]Has a note[/note]
            ...     [highlight]is highlighted[/highlight]
            ...     [elide]is elided[/elide]
            ...     [replace new content]is replaced[/replace]
            ...     [link http://example.com]is linked[/link]
            ... </p>'''
            >>> expected = '''<p>
            ...     <span class="annotate">Has a note</span><span custom-style="Footnote Reference">*</span>
            ...     <span class="annotate highlighted" custom-style="Highlighted Text">is highlighted</span>
            ...     <span custom-style="Elision">[ … ]</span>
            ...     <span custom-style="Replacement Text">new content</span>
            ...     <a class="annotate" href="http://example.com">is linked</a><span custom-style="Footnote Reference">**</span>
            ... </p>'''
            >>> assert_match(input, expected)

            Annotation spanning paragraphs:
            >>> input = '''
            ... <p>Some [highlight] text</p>
            ... <p>Some <em>text</em></p>
            ... <p>Some [/highlight] text</p>
            ... '''
            >>> expected = '''
            ... <p>Some <span class="annotate highlighted" custom-style="Highlighted Text"> text</span></p>
            ... <p><span class="annotate highlighted" custom-style="Highlighted Text">Some </span><em><span class="annotate highlighted" custom-style="Highlighted Text">text</span></em></p>
            ... <p><span class="annotate highlighted" custom-style="Highlighted Text">Some </span> text</p>
            ... '''
            >>> assert_match(input, expected)

            Deletion spanning paragraphs:
            >>> input = '''
            ... <p>Some [replace new content] text</p>
            ... <p>Some <em>text</em> <br></p>
            ... <p>Some [/replace] text</p>
            ... '''
            >>> expected = '''
            ... <p>Some <span custom-style="Replacement Text">new content</span></p><p> text</p>
            ... '''
            >>> assert_match(input, expected)

            Void elements:
            >>> input = '''<p> [highlight] <br> [/highlight] </p>'''
            >>> expected = '''<p> <span class="annotate highlighted" custom-style="Highlighted Text"> </span><br><span class="annotate highlighted" custom-style="Highlighted Text"> </span> </p>'''
            >>> assert_match(input, expected)

            Annotations with ambiguous placement:
            >>> input = '<p>First</p><p>[highlight]Second[/highlight]</p><p>Third</p>'
            >>> expected = '<p>First</p><p><span class="annotate highlighted" custom-style="Highlighted Text">Second</span></p><p>Third</p>'
            >>> assert_match(input, expected)
            >>> input = '<p>First</p><p>[elide]Second[/elide]</p><p>Third</p>'
            >>> expected = '<p>First</p><p><span custom-style="Elision">[ … ]</span></p><p>Third</p>'
            >>> assert_match(input, expected)
            >>> input = '<p>[highlight]First[/highlight]</p><p>[highlight]Sec[/highlight][highlight]ond[/highlight]</p><p>[highlight]Third[/highlight]</p>'
            >>> expected = '<p><span class="annotate highlighted" custom-style="Highlighted Text">First</span></p>' \
            ...     '<p><span class="annotate highlighted" custom-style="Highlighted Text">Sec</span><span class="annotate highlighted" custom-style="Highlighted Text">ond</span></p>' \
            ...     '<p><span class="annotate highlighted" custom-style="Highlighted Text">Third</span></p>'
            >>> assert_match(input, expected)

            Overlapping annotations:
            (Not sure if these can happen in practice, but they do work for export, at least in simple cases.)
            >>> input = '<p>[highlight]One [note my note]two[/highlight] three[/note]</p>'
            >>> expected = '<p><span class="annotate highlighted" custom-style="Highlighted Text">One <span class="annotate">two</span></span>' \
            ...     '<span class="annotate"> three</span><span custom-style="Footnote Reference">*</span></p>'
            >>> assert_match(input, expected)
            >>> input = '<p>[highlight]One [elide]two[/highlight] three[/elide]</p>'
            >>> expected = '<p><span class="annotate highlighted" custom-style="Highlighted Text">One <span custom-style="Elision">[ … ]</span></span></p>'
            >>> assert_match(input, expected)

            Annotations with invalid offsets are clamped:
            >>> input = '<p>[highlight]F[/highlight]oo</p>'
            >>> expected = '<p><span class="annotate highlighted" custom-style="Highlighted Text">Foo</span></p>'
            >>> resource = annotations_factory('Case', input)[1]
            >>> _ = resource.annotations.update(global_end_offset=1000)  # move end offset past end of text
            >>> assert resource.annotated_content_for_export() == expected
        """
        # Start with a sorted list of the start and end insertion points for each annotation.
        # Each entry in the list is shaped like (annotation_offset, is_start_tag, annotation).
        # Clamp offsets to the max valid value, as we may have legacy invalid values in the database that are too large.
        source_tree = parse_html_fragment(self.resource.content)
        max_valid_offset = len(source_tree.text_content())
        annotations = []
        for annotation in self.annotations.all():
            # equivalent test to self.annotations.valid(), but using all() lets us use prefetched querysets
            if annotation.global_start_offset < 0 or annotation.global_end_offset < 0:
                continue
            annotations.append((min(annotation.global_start_offset, max_valid_offset), True, annotation))
            annotations.append((min(annotation.global_end_offset, max_valid_offset), False, annotation))
        # sort by first two fields, so we're ordered by offset, then we get end tags and then start tags for a given offset
        annotations.sort(key=lambda a: a[:2])
        # This SAX ContentHandler does the heavy lifting of stepping through each HTML tag and text string in the
        # source HTML and building a list of destination tags and text, inserting annotation tags or deleting text
        # as appropriate:
        class AnnotationContentHandler(lxml.sax.ContentHandler):
            def __init__(self):
                # internal state:
                self.offset = 0  # current offset in the text stream
                self.elide = 0  # Greater than 0 if characters are currently being elided
                self.wrap_before_tags = []  # before emitting a tag, close these
                self.wrap_after_tags = []  # after emitting a tag, re-open these
                self.footnote_index = 0  # footnote count
                self.prev_tag = None  # previous source tag emitted
                self.skip_next_wrap_before = False  # whether to apply wrap_before_tags to the next element emitted

                # output state:
                self.out_handler = lxml.sax.ElementTreeContentHandler()  # the sax ContentHandler that will be used to generate the output
                self.out_ops = []  # list of operations to apply to the out_handler

            ## event handlers

            def characters(self, data):
                """
                    Called when the SAX parser encounters a text string in the source HTML. Handle each annotation
                    within the current string.
                """
                # calculate the range of annotations affected by this string:
                start_offset = self.offset
                self.offset = end_offset = start_offset + len(data)

                # special case -- don't annotate empty whitespace that comes after a block tag, because annotating
                # non-printing whitespace would insert empty paragraphs in the output:
                if (
                        # ... we have annotation spans open
                        self.wrap_after_tags and
                        # ... previous tag was closing a block-level element
                        self.prev_tag and self.prev_tag[0] == self.out_handler.endElement and self.prev_tag[
                    1] in block_level_elements and
                        # ... text after tag is whitespace
                        re.match(r'\s*$', data) and
                        # ... the text is not annotated
                        ((not annotations) or end_offset < annotations[0][0])
                ):
                    # remove the open spans added by the previous /tag
                    self.out_ops = self.out_ops[:-len(self.wrap_after_tags)]
                    # prevent spans from closing before the next tag
                    self.skip_next_wrap_before = True

                # Process each annotation within this character range.
                # Include end annotations that come after the final character of the string, but NOT start annotations,
                # so that annotations tend to go inside block tags -- start annotations go to the right of tags
                # and end annotations go to the left.
                while annotations and (
                        end_offset > annotations[0][0] or (end_offset == annotations[0][0] and not annotations[0][1])):
                    annotation_offset, is_start_tag, annotation = annotations.pop(0)

                    # consume and emit the text that comes before this annotation:
                    if annotation_offset > start_offset:
                        split = annotation_offset - start_offset
                        if not self.elide:
                            self.addText(data[:split])
                        data = data[split:]
                        start_offset = annotation_offset

                    # handle the annotation
                    kind = annotation.kind
                    if kind == 'replace' or kind == 'elide':
                        # replace/elide tags are simpler because we don't need to do anything special for annotations
                        # that span paragraphs. Just emit the elision text and increment elide when opening the tag,
                        # and decrement when closing. Use a counter for elide instead of a boolean so we handle
                        # overlapping elision ranges correctly (though those shouldn't happen in practice).
                        if is_start_tag:
                            self.out_ops.append((self.out_handler.startElement, 'span', {
                                'custom-style': 'Elision' if kind == 'elide' else 'Replacement Text'}))
                            self.addText(annotation.content or '' if kind == 'replace' else '[ … ]')
                            self.out_ops.append((self.out_handler.endElement, 'span'))
                            self.elide += 1
                        else:
                            self.elide = max(self.elide - 1, 0)  # decrement, but no lower than zero

                    else:  # kind == 'link' or 'note' or 'highlight'
                        # link/note/highlight tags require wrapping all subsequent text in <span> tags.
                        # In addition to emitting the open tags themselves, also add the open and close tags to
                        # wrap_before_tags and wrap_after_tags so that every tag we encounter can be wrapped with
                        # close and open tags for all open annotations.
                        if is_start_tag:
                            # get correct open and close tags for this annotation:
                            if kind == 'link':
                                open_tag = (
                                self.out_handler.startElement, 'a', {'href': annotation.content, 'class': 'annotate'})
                                close_tag = (self.out_handler.endElement, 'a')
                            elif kind == 'note':
                                open_tag = (self.out_handler.startElement, 'span', {'class': 'annotate'})
                                close_tag = (self.out_handler.endElement, 'span')
                            elif kind == 'highlight':
                                open_tag = (self.out_handler.startElement, 'span',
                                            {'class': 'annotate highlighted', 'custom-style': 'Highlighted Text'})
                                close_tag = (self.out_handler.endElement, 'span')
                            else:
                                raise ValueError("Unknown annotation kind '%s'" % kind)

                            # emit the open tag itself:
                            self.out_ops.append(open_tag)

                            # track that the tag is currently open:
                            self.wrap_after_tags.append(open_tag)
                            self.wrap_before_tags.insert(0, close_tag)
                            annotation.open_tag = open_tag
                            annotation.close_tag = close_tag
                        else:
                            # close the annotation tag:
                            # to handle overlapping annotations, close all tags including this one, and then re-open all tags except this one:
                            self.wrap_after_tags.remove(annotation.open_tag)
                            self.out_ops.extend(self.wrap_before_tags + self.wrap_after_tags)
                            self.wrap_before_tags.remove(annotation.close_tag)

                            # emit the footnote marker:
                            if kind == 'note' or kind == 'link':
                                self.footnote_index += 1
                                self.out_ops.append(
                                    (self.out_handler.startElement, 'span', {'custom-style': 'Footnote Reference'}))
                                self.addText('*' * self.footnote_index)
                                self.out_ops.append((self.out_handler.endElement, 'span'))

                # emit any text that comes after the final annotation in this text string:
                if data and not self.elide:
                    self.addText(data)

            def startElementNS(self, name, qname, attributes):
                """ Handle opening elements from the source HTML. """
                if self.omitTag(name[1]):
                    return
                self.addTag((self.out_handler.startElement, name[1], {k[1]: v for k, v in attributes.items()}))

            def endElementNS(self, name, qname):
                """ Handle closing elements from the source HTML. """
                if self.omitTag(name[1]):
                    return
                self.addTag((self.out_handler.endElement, name[1]))

            ## helpers

            def addTag(self, tag):
                """ Add a tag from the source HTML, wrapped with the currently open annotation tags. """
                if self.skip_next_wrap_before:
                    self.out_ops.extend([tag] + self.wrap_after_tags)
                    self.skip_next_wrap_before = False
                else:
                    self.out_ops.extend(self.wrap_before_tags + [tag] + self.wrap_after_tags)
                self.prev_tag = tag

            def addText(self, text):
                self.out_ops.append((self.out_handler.characters, text))

            def omitTag(self, tag):
                """
                    True if a tag from the source HTML should be omitted. This is True if we are currently in an
                    elided section, and this is a void element like '<br>'. We can't omit matched elements like
                    '<p>' because the elided section may end before we reach the closing '</p>'. Instead it's fine
                    to emit '<p></p>', which will later be filtered out by remove_empty_tags().
                """
                return self.elide and tag in void_elements

            def get_output_tree(self):
                """ Render and return the lxml content tree from out_handler. """
                # each entry in out_ops will be a method on out_handler and a list of arguments, like
                # (self.out_handler.startElement, 'span')
                for method, *args in self.out_ops:
                    method(*args)
                return self.out_handler.etree.getroot()

        # use AnnotationContentHandler to insert annotations in our content HTML:
        handler = AnnotationContentHandler()
        lxml.sax.saxify(source_tree, handler)
        dest_tree = handler.get_output_tree()

        # clean up the output tree:
        remove_empty_tags(dest_tree)  # tree may contain empty tags from elide/replace annotations
        # apply general rules that are the same for annotated or un-annotated trees
        self.update_tree_for_export(dest_tree)
        return mark_safe(inner_html(dest_tree))

    def footnote_annotations(self):
        return mark_safe("".join(
            format_html('<span custom-style="Footnote Reference">{}</span> {} ', "*" * (i + 1), annotation.content)
            for i, annotation in
            enumerate(a for a in self.annotations.all() if a.global_start_offset >= 0 and a.kind in ('note', 'link'))
        ))


    def is_transmutable(self):
        if self.headnote and len(self.headnote) > 0 or self.provenance:
            return False
        if self.resource_type == 'Temp' or self.resource_type == 'Unknown':
            return True
        if not self.resource_type or self.resource_type == 'Section' or self.resource_type == '':
            self.content_tree__load()
            return len(self.children) == 0
        else:
            if self.annotatable and self.is_annotated():
                return False
            if self.resource_type == 'TextBlock':
                try:
                    self.resource
                except ContentNode.DoesNotExist:
                    return True
                return self.resource and len(self.resource.content) < 10 # Reasonable heuristic?
            elif self.resource_type == 'Case':
                return True
            elif self.resource_type == 'Link':
                return True

    ##
    # Methods specialized by children
    ##

    @property
    def is_public(self):
        return self.new_casebook.is_public

    @property
    def is_private(self):
        return not self.is_public

    @property
    def permits_cloning(self):
        """
        Allow a user to clone this node.

        This method should be implemented by all children.
        """
        return self.new_casebook.permits_cloning

    def editable_by(self, user):
        return self.new_casebook.editable_by(user)

    @property
    def has_draft(self):
        return self.new_casebook.has_draft

    @property
    def is_draft(self):
        return self.new_casebook.is_draft

    def allows_draft_creation_by(self, user):
        return self.new_casebook.allows_draft_creation_by(user)

    def is_annotated(self):
        """
        While only Resources can be annotated, it is useful to know if a
        Casebook or Section contains Resources that have been annotated,
        and it is useful to have a single interface for finding Casebooks,
        Sections, and Resources associated with annotations.

        This method should be implemented by all children.
        """
        if self.resource_id:
            return self.annotations.count() > 0
        else:
            return any(node.annotations for node in self.contents.prefetch_related('annotations'))

    # URLs

    def get_absolute_url(self):
        """
        Since Casebooks, Sections, and Resources can all be accessed
        from URLs that include slugs AND from urls that omit slugs,
        instruct Django how to calculate the canonical URL for each object.
        https://docs.djangoproject.com/en/2.2/ref/models/instances/#get-absolute-url

        This method should be implemented by all children.
        """
        if self.resource_id or self.resource_type == 'Temp':
            return reverse('resource', args=[self.new_casebook, self])
        else:
            return reverse('section', args=[self.new_casebook, self])

    def get_edit_url(self):
        """
        A convenience method, for retrieving the edit URL of a Casebook,
        Section, or Resource without having to specify the view name,
        which is useful in shared templates.

        This method should be implemented by all children.
        """
        if self.resource_id or self.resource_type == 'Temp':
            return reverse('edit_resource', args=[self.new_casebook, self])
        else:
            return reverse('edit_section', args=[self.new_casebook, self])

    def get_draft_url(self):
        """
        If this node is or belongs to a Casebook that has a draft, return
        the URL of the draft's "edit" page. Otherwise, return a ValueError.

        This method should be implemented by all children.
        """
        return self.new_casebook.get_draft_url

    def get_edit_or_absolute_url(self, editing=False):
        """
        This is a convenience method, currently used only when building
        the Table of Contents. It probably will no longer be helpful,
        when the editable Table of Contents is rendered via Vue. But
        for now...

        This method should be implemented by all children.
        """
        if self.resource_id:
            if editing:
                if self.annotatable:
                    return self.get_annotate_url()
                return self.get_edit_url()
            return self.get_absolute_url()
        else:
            if editing:
                return self.get_edit_url()
            return self.get_absolute_url()

    @property
    def testing_editor(self):
        return self.new_casebook.testing_editor

    def clone_to(self, new_casebook):
        """
            Clone a section or resource from its current casebook to a new casebook.

            This is currently called only manually, for extraordinary customer service situations, but would ideally
            be exposed through the frontend.

            Given:
            >>> reset_sequences, full_casebook_parts_factory = [getfixture(i) for i in ['reset_sequences', 'full_casebook_parts_factory']]
            >>> from_casebook = full_casebook_parts_factory()[0]
            >>> to_casebook = full_casebook_parts_factory()[0]
            >>> section = from_casebook.sections[1]
            >>> resource = from_casebook.resources[0]

            Can append a section or a resource to the end of to_casebook:
            >>> section.clone_to(to_casebook)
            >>> resource.clone_to(to_casebook)
            >>> assert dump_casebook_outline(to_casebook)[-7:] == [
            ...   '   ContentNode<16> -> Case<4>: Foo Foo3 vs. Bar Bar3',
            ...   '    ContentAnnotation<7>: note 0-10',
            ...   '    ContentAnnotation<8>: replace 0-10',
            ...   '   ContentNode<17> -> Link<4>: Some Link Name 3',
            ...   ' Section<18>: Some Section 17',
            ...   ' ContentNode<19> -> Link<5>: Some Link Name 1',
            ...   ' ContentNode<20> -> TextBlock<5>: Some TextBlock Name 0'
            ... ]

            Ordinals are properly updated:
            >>> assert [node.ordinals for node in list(to_casebook.contents.all())] == [node.ordinals for node in list(from_casebook.contents.all())] + [[3], [4]]
        """
        contents = list(self.contents) if type(self) is Section or type(self) is Casebook else []
        new_casebook.clone_nodes(([self] if type(self) is not Casebook else []) + contents, append=True)

    @property
    def in_edit_state(self):
        return self.new_casebook.in_edit_state

    def tabs_for_user(self, user, current_tab=None):
        read_tab = 'Preview' if self.in_edit_state else 'Read'
        if current_tab is None:
            current_tab = read_tab
        tabs = [('Casebook', reverse('casebook', args=[self.new_casebook]), True),
                ('Edit', reverse('edit_resource', args=[self.new_casebook, self]), self.in_edit_state and self.editable_by(user)),
                ('Annotate', reverse('annotate_resource', args=[self.new_casebook, self]), self.in_edit_state and self.editable_by(user) and self.annotatable),
                (read_tab, reverse('section', args=[self.new_casebook, self]), True),
                ('Credits', reverse('show_resource_credits', args=[self.new_casebook, self]), True)]
        return [(n, l, n == current_tab) for n,l,c in tabs if c]


    @property
    def descendant_nodes(self):
        ids = [cn.id for cn in self.contents.all()] + [self.id]
        return ContentNode.objects.filter(provenance__overlap=ids).filter(new_casebook__state='Public')

    @property
    def ancestor_nodes(self):
        ids = [p for cn in self.contents.all() for p in cn.provenance] + [p for p in self.provenance]
        return ContentNode.objects.filter(id__in=ids).filter(new_casebook__state='Public')

    @property
    def related_cases(self):
        cases = None
        if self.resource_type == 'Case':
            cases = [self]
        else:
            cases = [x for x in self.contents.filter(resource_type='Case').prefetch_resources()]
        cap_ids = []
        res_ids = []
        for case in cases:
            if case.resource.capapi_id:
                cap_ids.append(case.resource.capapi_id)
            else:
                res_ids.append(case.resource.id)
        res_ids += [x.id for x in Case.objects.filter(capapi_id__in=cap_ids).all()]
        return ContentNode.objects.filter(resource_type='Case',resource_id__in=res_ids).filter(new_casebook__state='Public')


#
# Start ContentNode Proxies
#

class CasebookAndSectionMixin(models.Model):
    """
    Methods shared by Casebooks and Sections
    """

    class Meta:
        abstract = True

    def is_annotated(self):
        """See ContentNode.is_annotated"""
        return any(node.annotations for node in self.contents.prefetch_related('annotations'))

    def get_edit_or_absolute_url(self, editing=False):
        """See ContentNode.get_edit_or_absolute_url"""
        if editing:
            return self.get_edit_url()
        return self.get_absolute_url()

    def _delete_related_links_and_text_blocks(self):
        """
            A private utility for efficiently deleting associated Link and TextBlock objects.
        """
        to_delete = {Link: [], TextBlock: []}
        for resource in self.contents.prefetch_resources():
            if resource.resource_id and resource.resource_type in ('Link', 'TextBlock'):
                to_delete[type(resource._resource)].append(resource.resource_id)
        for cls, ids in to_delete.items():
            cls.objects.filter(id__in=ids).delete()

    @property
    def attributed_authors(self):
        return self.primary_authors.union(self.originating_authors)

    @property
    def originating_authors(self):
        """
        Every attributed author for any ancestor of a contentnode contained in the casebook
        """
        originating_node = set([cloned_node for child_content in self.contents.all() for cloned_node in child_content.provenance])
        users = [collaborator.user for cn in
                    ContentNode.objects.filter(id__in=originating_node)
                        .select_related('casebook')
                        .prefetch_related('casebook__tempcollaborator_set__user')
                        .all()
                    for collaborator in cn.new_casebook.tempcollaborator_set.all() if collaborator.has_attribution and collaborator.user.attribution != 'Anonymous']
        return set(users)

    @property
    def has_non_current_authors(self):
        return len(self.non_current_authors) > 0

    @property
    def non_current_authors(self):
        ogs = self.originating_authors
        cgs = self.primary_authors
        return ogs.difference(cgs)

class SectionAndResourceMixin(models.Model):
    """
    Methods shared by Sections and Resources
    """

    class Meta:
        abstract = True

    def delete(self, *args, **kwargs):
        """
            Override delete, to ensure the tree is re-ordered afterwards,
            and to clean up now-unused TextBlock and Link resources.

            Given:
            >>> full_casebook_parts_factory, assert_num_queries = [getfixture(i) for i in ['full_casebook_parts_factory','assert_num_queries']]

            # Sections
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = full_casebook_parts_factory()

            Delete a section in a section (and children, including one case, one text block, and one link/default), no reordering required:
            >>> with assert_num_queries(delete=5, select=13, update=1, insert=8):
            ...     deleted = s_1_4.delete()
            >>> assert deleted == (6, {'main.Section': 1, 'main.ContentAnnotation': 2, 'main.ContentNode': 3})
            >>> assert dump_content_tree(casebook) == [
            ...         [s_1, casebook, [
            ...             [r_1_1, s_1, []],
            ...             [r_1_2, s_1, []],
            ...             [r_1_3, s_1, []],
            ...         ]],
            ...         [s_2, casebook, []],
            ... ]
            >>> for node in [s_1_4, r_1_4_1, r_1_4_2, r_1_4_3]:
            ...     with assert_raises(ContentNode.DoesNotExist):
            ...         node.refresh_from_db()

            Delete the first section in the book (and children, including one case, one text block, and one link/default), triggering reordering:
            >>> with assert_num_queries(delete=5, select=12, update=1, insert=8):
            ...     deleted = s_1.delete()
            >>> assert deleted == (6, {'main.Section': 1, 'main.ContentAnnotation': 2, 'main.ContentNode': 3})
            >>> assert dump_content_tree(casebook) == [
            ...         [s_2, casebook, []],
            ... ]
            >>> for node in [s_1, r_1_1, r_1_2, r_1_3]:
            ...     with assert_raises(ContentNode.DoesNotExist):
            ...         node.refresh_from_db()
            >>> s_2.refresh_from_db()
            >>> assert s_2.ordinals == [1]

            # Resources
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')

            Delete a case resource in the middle of a section:
            >>> with assert_num_queries(delete=2, select=4, update=1, insert=3):
            ...     deleted = r_1_2.delete()
            >>> assert deleted == (3, {'main.Resource': 1, 'main.ContentAnnotation': 2})
            >>> assert dump_content_tree(casebook) == [
            ...     [s_1, casebook, [
            ...         [r_1_1, s_1, []],
            ...         [r_1_3, s_1, []],
            ...         [s_1_4, s_1, [
            ...             [r_1_4_1, s_1_4, []],
            ...             [r_1_4_2, s_1_4, []],
            ...             [r_1_4_3, s_1_4, []],
            ...         ]],
            ...     ]],
            ...     [s_2, casebook, []],
            ... ]
            >>> with assert_raises(Resource.DoesNotExist):
            ...     r_1_2.refresh_from_db()
            >>> r_1_3.refresh_from_db()
            >>> s_1_4.refresh_from_db()
            >>> assert all([r_1_1.ordinals == [1,1], r_1_3.ordinals == [1,2], s_1_4.ordinals == [1,3]])

            Delete a text resource at the beginning of a section:
            >>> r_1_4_1.refresh_from_db()
            >>> with assert_num_queries(delete=2, select=6, update=1, insert=2):
            ...     deleted = r_1_4_1.delete()
            >>> assert deleted == (2, {'main.Resource': 1, 'main.TextBlock': 1})
            >>> assert dump_content_tree(casebook) == [
            ...     [s_1, casebook, [
            ...         [r_1_1, s_1, []],
            ...         [r_1_3, s_1, []],
            ...         [s_1_4, s_1, [
            ...             [r_1_4_2, s_1_4, []],
            ...             [r_1_4_3, s_1_4, []],
            ...         ]],
            ...     ]],
            ...     [s_2, casebook, []],
            ... ]
            >>> with assert_raises(Resource.DoesNotExist):
            ...     r_1_4_1.refresh_from_db()

            Delete a link/default resource at the end of a section:
            >>> r_1_4_3.refresh_from_db()
            >>> with assert_num_queries(delete=2, select=6, update=1, insert=2):
            ...     deleted = r_1_4_3.delete()
            >>> assert deleted == (2, {'main.Resource': 1, 'main.Link': 1})
            >>> assert dump_content_tree(casebook) == [
            ...     [s_1, casebook, [
            ...         [r_1_1, s_1, []],
            ...         [r_1_3, s_1, []],
            ...         [s_1_4, s_1, [
            ...             [r_1_4_2, s_1_4, []],
            ...         ]],
            ...     ]],
            ...     [s_2, casebook, []],
            ... ]
            >>> with assert_raises(Resource.DoesNotExist):
            ...     r_1_4_3.refresh_from_db()

        """
        # Find this nodes's parent
        ordinals_of_parent = self.ordinals[:-1]
        if ordinals_of_parent:
            parent = ContentNode.objects.get(new_casebook=self.new_casebook, ordinals=ordinals_of_parent)
        else:
            parent = self.new_casebook

        # Delete this nodes's children, and any related links and textblocks,
        # without recursively calling our custom Section.delete and Resource.delete methods
        # https://docs.djangoproject.com/en/2.2/topics/db/queries/#deleting-objects
        child_total = 0
        child_deletes = {}
        if self.resource_type in ['', 'Section', None]:
            self._delete_related_links_and_text_blocks()
            child_total, child_deletes = self.contents.delete()
        elif self.resource_type in ['TextBlock', 'Link']:
            child_total, child_deletes = self.resource.delete()

        # Delete this node
        return_total, return_dict = super().delete(*args, **kwargs)

        # Update the ordinals of the content tree
        parent.content_tree__repair()

        for k,v in child_deletes.items():
            return_dict[k] = return_dict.get(k,0) + v
        return (return_total + child_total, return_dict)

    @property
    def is_public(self):
        """See ContentNode.is_public"""
        return self.new_casebook.is_public

    def editable_by(self, user):
        """See ContentNode.editable_by"""
        return self.new_casebook.editable_by(user)

    @property
    def permits_cloning(self):
        """See ContentNode.permits_cloning"""
        return self.new_casebook.permits_cloning

    @property
    def has_draft(self):
        """See ContentNode.has_draft"""
        return self.new_casebook.has_draft

    def allows_draft_creation_by(self, user):
        """See ContentNode.allows_draft_creation_by"""
        return self.new_casebook.allows_draft_creation_by(user)

    def get_draft_url(self):
        """See ContentNode.get_draft_url"""
        return self.new_casebook.get_draft_url()

class CommonTitle(BigPkModel):
    name = models.CharField(max_length=300, blank=False, null=False)
    public_url = models.CharField(max_length=300, blank=False, null=False, validators=[validate_unicode_slug])
    current = models.ForeignKey('Casebook', on_delete=models.DO_NOTHING, blank=False, null=False, related_name='title_name')

    class Meta:
        managed = True

    def public_casebooks(self):
        return Casebook.objects.filter(common_title=self).exclude(state=Casebook.LifeCycle.ARCHIVED.value).exclude(state=Casebook.LifeCycle.DRAFT.value).exclude(state=Casebook.LifeCycle.PREVIOUS_SAVE.value)

class Casebook(EditTrackedModel, TimestampedModel, BigPkModel, CasebookAndSectionMixin, TrackedCloneable):
    old_casebook = models.ForeignKey('ContentNode', on_delete=models.DO_NOTHING,blank=True,null=True,related_name='replacement_casebook')
    title = models.CharField(max_length=10000, default="Untitled")
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)

    collaborators = models.ManyToManyField('User',
                                           through='TempCollaborator',
                                           related_name='casebooks'
                                           )
    @property
    def contentcollaborator_set(self):
        return self.tempcollaborator_set

    class LifeCycle(Enum):
        PRIVATELY_EDITING = 'Fresh' # There is no public version of this casebook
        NEWLY_CLONED = 'Clone' # There is no public version of this casebook
        DRAFT = 'Draft' # This version is private, but a public version exists
        PUBLISHED = 'Public' # This version is public
        ARCHIVED = 'Archived' # This is retired, and is no longer public
        REVISING = 'Revising' # A public and private (with edits) version of this casebook exist.
        PREVIOUS_SAVE = 'Previous' # A casebook that has been replaced with a merged draft

    state = models.CharField(
      max_length=10,
      choices=[(tag.value, tag.name) for tag in LifeCycle]
    )
    draft = models.OneToOneField(
        'self',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name='draft_of',
        unique=True,
    )
    history = HistoricalRecords()
    common_title = models.ForeignKey(
        'CommonTitle',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='casebooks'
    )

    tracked_fields = ['headnote']

    class Meta:
        managed = True

    def save(self, *args, **kwargs):
        r"""
            Override save to include the cleanup of user-supplied HTML.

            Given:
            >>> caplog, _ = [getfixture(i) for i in ['caplog', 'db']]
            >>> html = '<p>Prepended</p>\n\n<p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\n</p>'
            >>> cleaned_html = '<p>Prepended</p><p>\n  <em>Keep foo keep baz buzz add boo</em>\n</p>'

            On save, the headnote is cleansed.
            >>> node = ContentNode(headnote=html)
            >>> with caplog.at_level(logging.DEBUG):
            ...     node.headnote = html
            ...     node.save()
            >>> node.refresh_from_db()
            >>> assert node.headnote == cleaned_html
        """
        cleanse_html_field(self, 'headnote', True)
        super().save(*args, **kwargs)

    def get_slug(self):
        return slugify(self.title)

    def viewable_by(self, user):
        if (not (self.is_archived or self.is_previous_save)) and (self.is_public or user.is_superuser):
            return True
        return bool(self.tempcollaborator_set.filter(user_id=user.id).first())


    def directly_editable_by(self, user):
        """
        Allow a user to make real-time changes (e.g., via edit view),
        rather than requiring them to make changes via the draft mechanism.
        (See allows_draft_creation_by for more discussion of editing and drafts.)
        """
        return self.is_private and self.editable_by(user)

    def __str__(self):
        return "{} ({})".format(self.title, self.id)

    @property
    def type(self):
        # TODO: In use in templates and tests; shouldn't be necessary. Consider refactoring.
        return type(self).__name__.lower()

    def headnote_for_export(self):
        r"""
            Return headnote HTML prepared for pandoc export.

            >>> assert Resource(headnote='<p>An image <img src=""></p>').headnote_for_export() == '<p>An image </p>'
        """
        if not self.headnote:
            return ''
        tree = parse_html_fragment(self.headnote)
        PyQuery(tree).remove('img')
        return mark_safe(inner_html(tree))

    @property
    def is_resource(self):
        return False

    @property
    def is_public(self):
        return self.state == Casebook.LifeCycle.PUBLISHED.value

    @property
    def is_private(self):
        return not self.is_public

    def get_edit_or_absolute_url(self, editing=False):
        """See ContentNode.get_edit_or_absolute_url"""
        if editing:
            return self.get_edit_url()
        return self.get_absolute_url()

    def delete(self, *args, **kwargs):
        """
            Override delete, to ensure that a Casebook is deleted in its entirety.

            Casebook contents and ContentCollaborators would normally be deleted by setting
            Django's `on_delete` attribute to CASCADE, but since we don't want this
            behavior during the deletion of all ContentNode objects, only of Casebooks,
            we have to take care of it manually.

            Similarly, the manual deletion of related Links and TextBlocks is due to
            limitations in our current data model, where Resource objects are not
            tied to their related Case/TextBlock/Link objects via foreign keys.

            Given:
            >>> assert_num_queries = getfixture('assert_num_queries')
            >>> nodes = getfixture('full_casebook_parts_with_draft')
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = nodes
            >>> draft = casebook.draft
            >>> assert casebook.contentcollaborator_set.count() == 1

            >>> assert Casebook.objects.exists()
            >>> assert ContentNode.objects.exists()
            >>> assert ContentAnnotation.objects.exists()
            >>> with assert_num_queries(delete=12, select=18, insert=36):
            ...     deleted = casebook.delete()
            >>> assert not Casebook.objects.exists()
            >>> assert not ContentNode.objects.exists()
            >>> assert not ContentAnnotation.objects.exists()
            >>> assert casebook.tempcollaborator_set.count() == 0
        """
        if self.draft:
            self.draft.delete()
        self._delete_related_links_and_text_blocks()
        self.contents.all().delete()
        self.contentcollaborator_set.all().delete()
        return super().delete(*args, **kwargs)

    @property
    def sections(self):
        return Section.objects.filter(new_casebook=self)

    @property
    def resources(self):
        return ContentNode.objects.filter(new_casebook=self,resource_id__isnull=False)

    @property
    def children(self):
        return ContentNode.objects.filter(new_casebook=self, ordinals__len=1)

    @property
    def descendant_nodes(self):
        ids = [cn.id for cn in self.contents.all()]
        return ContentNode.objects.filter(provenance__overlap=ids).filter(new_casebook__state='Public')

    @property
    def ancestor_nodes(self):
        ids = [p for cn in self.contents.all() for p in cn.provenance]
        return ContentNode.objects.filter(id__in=ids).filter(new_casebook__state='Public')

    @property
    def related_cases(self):
        cases = None
        cases = [x for x in self.contents.filter(resource_type='Case').prefetch_resources()]
        cap_ids = []
        res_ids = []
        for case in cases:
            if case.resource.capapi_id:
                cap_ids.append(case.resource.capapi_id)
            else:
                res_ids.append(case.resource.id)
        res_ids += [x.id for x in Case.objects.filter(capapi_id__in=cap_ids).all()]
        return ContentNode.objects.filter(resource_type='Case',resource_id__in=res_ids).filter(new_casebook__state="Public")

    @property
    def previous_saves(self):
        target_provenance = self.provenance + [self.id]
        return Casebook.objects.filter(provenance=target_provenance, state=Casebook.LifeCycle.PREVIOUS_SAVE.value).order_by('-updated_at')

    @transaction.atomic
    def restore_from_save(self):
        if not self.state == Casebook.LifeCycle.PREVIOUS_SAVE.value:
            raise ValueError("Bad restore state")
        current_casebook = self.version_tree__parent()
        savepoint = self

        # swap all attributes
        #start with the fields
        for attr in ('title', 'subtitle', 'headnote'):
            setattr(current_casebook, attr, getattr(savepoint, attr))

        current_casebook._delete_related_links_and_text_blocks()
        cloned_resources, cloned_content_nodes, cloned_annotations = current_casebook.collect_cloning_nodes(node for node in savepoint.contents.all())
        current_casebook.save_and_parent_cloned_resources(cloned_resources)
        for ccn in cloned_content_nodes:
            ccn.provenance.pop()
        bulk_create_with_history(cloned_content_nodes, ContentNode, batch_size=500, default_change_reason="Restore from {}".format(self.id))
        current_casebook.save_and_parent_cloned_annotations(cloned_annotations)

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse('casebook', args=[self])

    @property
    def view_url(self):
        return self.get_absolute_url()

    def get_draft_url(self):
        """See ContentNode.get_draft_url"""
        if self.draft:
            return reverse('edit_casebook', args=[self.draft])
        raise ValueError("This casebook doesn't have a draft.")

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse('edit_casebook', args=[self])

    def editable_by(self, user):
        """See ContentNode.editable_by"""
        if not user.is_authenticated:
            return False
        collabs = self.tempcollaborator_set.filter(user=user).first()
        return user.is_superuser or (collabs and collabs.can_edit)

    @property
    def permits_cloning(self):
        """See ContentNode.permits_cloning"""
        return self.state not in {Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.PREVIOUS_SAVE.value}

    @property
    def has_draft(self):
        """See ContentNode.has_draft"""
        return bool(self.draft)

    @property
    def is_draft(self):
        return self.state == Casebook.LifeCycle.DRAFT.value

    def allows_draft_creation_by(self, user):
        """See ContentNode.allows_draft_creation_by"""
        return self.is_public and self.editable_by(user) and not self.has_draft

    def make_draft(self):
        """
            Clone casebook in draft mode, copying existing collaborators.

            Given:
            >>> full_casebook, user = [getfixture(i) for i in ['full_casebook', 'user']]
            >>> full_casebook.add_collaborator(user)
            >>> draft = full_casebook.make_draft()

            `draft` will be in draft mode and will have the same collaborators as the original:
            >>> assert draft.is_draft is True
            >>> assert (set((c.user) for c in full_casebook.contentcollaborator_set.all()) ==
            ...         set((c.user) for c in draft.contentcollaborator_set.all()))
        """
        return self.clone(draft_mode=True)

    @transaction.atomic
    def merge_draft(self):
        """
            Merge draft casebook back into parent, and delete draft.

            Given:
            >>> reset_sequences, full_casebook, assert_num_queries = [getfixture(i) for i in ['reset_sequences', 'full_casebook', 'assert_num_queries']]
            >>> elena, john =  [User(attribution=name, email_address="{}@scotus.gov".format(name)) for name in ['Elena', 'John']]
            >>> elena.save()
            >>> john.save()
            >>> full_casebook.add_collaborator(elena, has_attribution=True)
            >>> section = full_casebook.contents.first()
            >>> section.provenance = [100]
            >>> section.save()
            >>> original_provenances = [x.provenance for x in full_casebook.contents.all()]
            >>> second_casebook = full_casebook.clone(current_user=john)
            >>> draft = full_casebook.make_draft()

            Merge draft back into original:
            >>> draft.title = "New Title"
            >>> draft.save()
            >>> Section(new_casebook=draft, ordinals=[3], title="New Section").save()
            >>> with assert_num_queries(select=2, update=3, insert=3):
            ...     new_casebook = draft.merge_draft()
            >>> assert new_casebook == full_casebook
            >>> expected = [
            ...       'Casebook<1>: New Title',
            ...       ' Section<19>: Some Section 0',
            ...       '  ContentNode<20> -> TextBlock<5>: Some TextBlock Name 0',
            ...       '  ContentNode<21> -> Case<1>: Foo Foo0 vs. Bar Bar0',
            ...       '   ContentAnnotation<9>: highlight 0-10',
            ...       '   ContentAnnotation<10>: elide 0-10',
            ...       '  ContentNode<22> -> Link<5>: Some Link Name 0',
            ...       '  Section<23>: Some Section 4',
            ...       '   ContentNode<24> -> TextBlock<6>: Some TextBlock Name 1',
            ...       '   ContentNode<25> -> Case<2>: Foo Foo1 vs. Bar Bar1',
            ...       '    ContentAnnotation<11>: note 0-10',
            ...       '    ContentAnnotation<12>: replace 0-10',
            ...       '   ContentNode<26> -> Link<6>: Some Link Name 1',
            ...       ' Section<27>: Some Section 8',
            ...       ' Section<28>: New Section'
            ... ]
            >>> assert dump_casebook_outline(new_casebook) == expected

            The original copy_of attributes from the published version are preserved:
            >>> full_casebook.refresh_from_db()
            >>> assert original_provenances + [[]] == [x.provenance for x in full_casebook.contents.all()]

            Clones of the original casebook have proper attribution
            >>> assert elena in second_casebook.attributed_authors
        """
        # set up variables
        draft = self
        if not self.is_draft:
            raise ValueError("Only draft casebooks may be merged")
        parent = self.draft_of

        # swap all attributes

        #start with the fields
        for attr in ('title', 'subtitle', 'headnote'):
            temp = getattr(draft, attr)
            setattr(draft, attr, getattr(parent, attr))
            setattr(parent, attr, temp)


        # state
        # parent.state stays public
        draft.state = Casebook.LifeCycle.PREVIOUS_SAVE.value

        # update relations
        # draft

        parent.draft = None
        draft.draft = None

        # content nodes

        to_publish = [x for x in draft.contents.all()]
        to_retire = [cn for cn in parent.contents.all()]
        for content_node in to_publish:
            if content_node.provenance:
                content_node.provenance.pop()
            content_node.new_casebook = parent
        for content_node in to_retire:
            content_node.new_casebook = draft

        bulk_update_with_history(to_publish + to_retire, ContentNode, ['new_casebook_id', 'provenance'], batch_size=500, default_change_reason="Draft Merge")
        draft._change_reason = "Draft Merge"
        draft.save()
        parent._change_reason = "Draft Merge"
        parent.save()

        return parent

    @transaction.atomic
    def clone(self, current_user=None, draft_mode=False):
        """
            Clone casebook with all of its assets. If User object `current_user` is provided, that user will replace the
            existing users. If draft_mode=True, clone will be marked as a draft.

            Given an initial casebook like this:
            >>> reset_sequences, full_casebook, user, assert_num_queries = [getfixture(i) for i in ['reset_sequences', 'full_casebook', 'user', 'assert_num_queries']]
            >>> expected = [
            ...   'Casebook<1>: Some Title 0',
            ...   ' Section<1>: Some Section 0',
            ...   '  ContentNode<2> -> TextBlock<1>: Some TextBlock Name 0',
            ...   '  ContentNode<3> -> Case<1>: Foo Foo0 vs. Bar Bar0',
            ...   '   ContentAnnotation<1>: highlight 0-10',
            ...   '   ContentAnnotation<2>: elide 0-10',
            ...   '  ContentNode<4> -> Link<1>: Some Link Name 0',
            ...   '  Section<5>: Some Section 4',
            ...   '   ContentNode<6> -> TextBlock<2>: Some TextBlock Name 1',
            ...   '   ContentNode<7> -> Case<2>: Foo Foo1 vs. Bar Bar1',
            ...   '    ContentAnnotation<3>: note 0-10',
            ...   '    ContentAnnotation<4>: replace 0-10',
            ...   '   ContentNode<8> -> Link<2>: Some Link Name 1',
            ...   ' Section<9>: Some Section 8'
            ... ]

            >>> assert dump_casebook_outline(full_casebook) == expected
            >>> assert user not in set(full_casebook.attributed_authors)

            Return a cloned casebook like this:
            >>> with assert_num_queries(select=6, insert=11):
            ...     clone = full_casebook.clone(current_user=user)
            >>> expected = [
            ...      'Casebook<2>: Some Title 0',
            ...      ' Section<10>: Some Section 0',
            ...      '  ContentNode<11> -> TextBlock<3>: Some TextBlock Name 0',
            ...      '  ContentNode<12> -> Case<1>: Foo Foo0 vs. Bar Bar0',
            ...      '   ContentAnnotation<5>: highlight 0-10',
            ...      '   ContentAnnotation<6>: elide 0-10',
            ...      '  ContentNode<13> -> Link<3>: Some Link Name 0',
            ...      '  Section<14>: Some Section 4',
            ...      '   ContentNode<15> -> TextBlock<4>: Some TextBlock Name 1',
            ...      '   ContentNode<16> -> Case<2>: Foo Foo1 vs. Bar Bar1',
            ...      '    ContentAnnotation<7>: note 0-10',
            ...      '    ContentAnnotation<8>: replace 0-10',
            ...      '   ContentNode<17> -> Link<4>: Some Link Name 1',
            ...      ' Section<18>: Some Section 8'
            ... ]
            >>> assert dump_casebook_outline(clone) == expected
            >>> assert user in set(clone.attributed_authors)
            >>> assert clone.provenance == [full_casebook.id]
            >>> assert clone.state == Casebook.LifeCycle.NEWLY_CLONED.value
            >>> clone_of_clone = clone.clone(current_user=user)
            >>> assert clone_of_clone.provenance == [full_casebook.id, clone.id]
            >>> clone3 = clone_of_clone.clone(current_user=user)
            >>> assert clone3.provenance == [full_casebook.id, clone.id, clone_of_clone.id]

            Attribution and cloning
            >>> casebook = getfixture('full_casebook')
            >>> sonya, elena, john = [User(attribution=name, email_address="{}@scotus.gov".format(name)) for name in ['Sonya', 'Elena', 'John']]
            >>> sonya.save(); elena.save(); john.save()
            >>> casebook.add_collaborator(sonya, has_attribution=True)
            >>> casebook.save()
            >>> first_clone = casebook.clone(current_user=elena)
            >>> first_clone.save()
            >>> first_clone.refresh_from_db()
            >>> assert sonya in first_clone.attributed_authors
            >>> assert elena in first_clone.attributed_authors
            >>> assert elena not in casebook.attributed_authors
            >>> second_clone = first_clone.clone(current_user=elena)
            >>> assert sonya in second_clone.originating_authors
            >>> assert elena in second_clone.primary_authors
            >>> assert second_clone.editable_by(elena)
            >>> assert not second_clone.editable_by(sonya)
            >>> casebook.add_collaborator(john, has_attribution=True)
            >>> assert john in casebook.attributed_authors
            >>> assert john in first_clone.attributed_authors
            >>> assert john in second_clone.originating_authors
        """
        # clone casebook
        old_casebook = self
        cloned_casebook = clone_model_instance(old_casebook,
                                               public=False,
                                               old_casebook=None,
                                               provenance=self.provenance + [self.id],
                                               draft=None,
                                               state=(Casebook.LifeCycle.DRAFT.value if draft_mode else Casebook.LifeCycle.NEWLY_CLONED.value))
        cloned_casebook.save()

        # If this is a draft, collaborators stay the same,
        # Otherwise, we just add one collaborator (the current_user)
        if draft_mode:
            collaborators = [clone_model_instance(c, casebook=cloned_casebook, can_edit=c.can_edit) for c in
                             self.contentcollaborator_set.all()]
            TempCollaborator.objects.bulk_create(collaborators) # Currently no History on Collaborators
            self.draft = cloned_casebook
            self.save()
        elif current_user:
            cloned_casebook.add_collaborator(user=current_user, has_attribution=True, can_edit=True)

        cloned_casebook.clone_nodes(old_casebook.contents.prefetch_resources().prefetch_related('annotations')
                                    .select_related('new_casebook')
                                    .prefetch_related('new_casebook__tempcollaborator_set'),
                                    draft_mode=draft_mode)
        return cloned_casebook

    def collect_cloning_nodes(self, nodes):
        # clone contents
        cloned_resources = {TextBlock: [], Link: []}  # collect new TextBlocks and Links for bulk_create
        cloned_content_nodes = []  # collect new ContentNodes for bulk_create
        cloned_annotations = []  # collect new ContentAnnotations for bulk_create

        for old_content_node in nodes:
            # clone content_node
            cloned_content_node = clone_model_instance(old_content_node,
                                                       casebook=None,
                                                       provenance=old_content_node.provenance + [old_content_node.id],
                                                       new_casebook=self)
            cloned_content_nodes.append(cloned_content_node)

            # clone annotations
            for old_annotation in old_content_node.annotations.all():
                cloned_annotation = clone_model_instance(old_annotation)
                cloned_annotations.append((cloned_annotation, cloned_content_node))

            # clone resources
            if old_content_node.resource_id and old_content_node.resource_type != 'Case':
                resource = old_content_node.resource
                cloned_resource = clone_model_instance(resource)
                cloned_resources[type(cloned_resource)].append((cloned_resource, cloned_content_node))

        return cloned_resources, cloned_content_nodes, cloned_annotations

    def save_and_parent_cloned_resources(self, cloned_resources):
        # save TextBlocks and Links
        for resource_class, resources in cloned_resources.items():
            bulk_create_with_history((r[0] for r in resources), resource_class, batch_size=500, default_change_reason="Clone Create")
            # after saving, update the associated cloned_content_nodes to point to the new resource_ids
            for cloned_resource, cloned_content_node in resources:
                cloned_content_node.resource_id = cloned_resource.id


    def save_and_parent_cloned_annotations(self, cloned_annotations):
        # save ContentAnnotations (first update cloned_annotations to point to the new content_node IDs)
        for cloned_annotation, cloned_content_node in cloned_annotations:
            cloned_annotation.resource = cloned_content_node
        bulk_create_with_history((r[0] for r in cloned_annotations), ContentAnnotation, batch_size=500, default_change_reason="Clone Create")


    @transaction.atomic
    def clone_nodes(self, nodes, draft_mode=False, append=False):
        """
            Helper method to copy a set of nodes and their associated assets to this casebook. See callers for tests.
            If append=True, ordinals will be edited so the new nodes appear after any existing nodes.
        """
        cloned_resources, cloned_content_nodes, cloned_annotations = self.collect_cloning_nodes(nodes)

        self.save_and_parent_cloned_resources(cloned_resources)

        # save ContentNodes
        if append:
            # offset cloned nodes so they go at the end of the current tree.
            # "offset" is the count of existing top-level content_tree nodes:
            offset = \
            (ContentNode.objects.filter(new_casebook_id=self).aggregate(models.Max('ordinals'))['ordinals__max'] or [0])[
                0] + 1
            for node in cloned_content_nodes:
                node.ordinals[0] += offset
        bulk_create_with_history(cloned_content_nodes, ContentNode, batch_size=500, default_change_reason="Clone Create")
        if append:
            # if we offset the ordinals to push the new nodes to the end, then they will be in the right order
            # but might be non-consecutive or overly nested; call _repair to clean them up
            self.content_tree__repair()

        self.save_and_parent_cloned_annotations(cloned_annotations)


    def archive(self):
        self.state = Casebook.LifeCycle.ARCHIVED.value
        self.save()

    def unarchive(self):
        self.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
        self.save()

    @property
    def is_archived(self):
        return self.state == Casebook.LifeCycle.ARCHIVED.value

    @property
    def can_archive(self):
        return self.can_transition_to(Casebook.LifeCycle.ARCHIVED)

    @property
    def is_previous_save(self):
        return self.state == Casebook.LifeCycle.PREVIOUS_SAVE.value


    @property
    def can_depublish(self):
        return self.is_public and self.can_transition_to(Casebook.LifeCycle.PRIVATELY_EDITING)

    def depublish(self):
        if not (self.can_depublish):
            raise ValueError("Cannot depublish this casebook")
        self.state = Casebook.LifeCycle.PRIVATELY_EDITING
        self.save()

    @property
    def can_publish(self):
        if len([x for x in self.contents.all() if x.is_temporary]) > 0:
            return False
        return self.can_transition_to(Casebook.LifeCycle.PUBLISHED) or self.is_draft or self.has_draft

    def can_transition_to(self, target):
        target_value = (hasattr(target, 'value') and target.value) or target
        if self.state == target_value:
            return False

        transition_options = {
            (Casebook.LifeCycle.PRIVATELY_EDITING.value,Casebook.LifeCycle.NEWLY_CLONED.value):False,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value,Casebook.LifeCycle.DRAFT.value):False,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value,Casebook.LifeCycle.PUBLISHED.value):True,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value,Casebook.LifeCycle.REVISING.value):False,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value,Casebook.LifeCycle.ARCHIVED.value):True,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value,Casebook.LifeCycle.PREVIOUS_SAVE.value):True,

            (Casebook.LifeCycle.NEWLY_CLONED.value,Casebook.LifeCycle.PRIVATELY_EDITING.value):True,
            (Casebook.LifeCycle.NEWLY_CLONED.value,Casebook.LifeCycle.DRAFT.value):False,
            (Casebook.LifeCycle.NEWLY_CLONED.value,Casebook.LifeCycle.PUBLISHED.value):True,
            (Casebook.LifeCycle.NEWLY_CLONED.value,Casebook.LifeCycle.REVISING.value):False,
            (Casebook.LifeCycle.NEWLY_CLONED.value,Casebook.LifeCycle.ARCHIVED.value):True,
            (Casebook.LifeCycle.NEWLY_CLONED.value,Casebook.LifeCycle.PREVIOUS_SAVE.value):False,

            (Casebook.LifeCycle.DRAFT.value,Casebook.LifeCycle.PRIVATELY_EDITING.value):False,
            (Casebook.LifeCycle.DRAFT.value,Casebook.LifeCycle.NEWLY_CLONED.value):False,
            (Casebook.LifeCycle.DRAFT.value,Casebook.LifeCycle.PUBLISHED.value):True,
            (Casebook.LifeCycle.DRAFT.value,Casebook.LifeCycle.REVISING.value):False,
            (Casebook.LifeCycle.DRAFT.value,Casebook.LifeCycle.ARCHIVED.value):False,
            (Casebook.LifeCycle.DRAFT.value,Casebook.LifeCycle.PREVIOUS_SAVE.value):True,

            (Casebook.LifeCycle.PUBLISHED.value,Casebook.LifeCycle.PRIVATELY_EDITING.value):True,
            (Casebook.LifeCycle.PUBLISHED.value,Casebook.LifeCycle.NEWLY_CLONED.value):False,
            (Casebook.LifeCycle.PUBLISHED.value,Casebook.LifeCycle.DRAFT.value):False,
            (Casebook.LifeCycle.PUBLISHED.value,Casebook.LifeCycle.REVISING.value):True,
            (Casebook.LifeCycle.PUBLISHED.value,Casebook.LifeCycle.ARCHIVED.value):False,
            (Casebook.LifeCycle.PUBLISHED.value,Casebook.LifeCycle.PREVIOUS_SAVE.value):False,

            (Casebook.LifeCycle.REVISING.value,Casebook.LifeCycle.PRIVATELY_EDITING.value):True,
            (Casebook.LifeCycle.REVISING.value,Casebook.LifeCycle.NEWLY_CLONED.value):False,
            (Casebook.LifeCycle.REVISING.value,Casebook.LifeCycle.DRAFT.value):False,
            (Casebook.LifeCycle.REVISING.value,Casebook.LifeCycle.PUBLISHED.value):True,
            (Casebook.LifeCycle.REVISING.value,Casebook.LifeCycle.ARCHIVED.value):False,
            (Casebook.LifeCycle.REVISING.value,Casebook.LifeCycle.PREVIOUS_SAVE.value):False,

            (Casebook.LifeCycle.ARCHIVED.value,Casebook.LifeCycle.PRIVATELY_EDITING.value):True,
            (Casebook.LifeCycle.ARCHIVED.value,Casebook.LifeCycle.NEWLY_CLONED.value):False,
            (Casebook.LifeCycle.ARCHIVED.value,Casebook.LifeCycle.DRAFT.value):False,
            (Casebook.LifeCycle.ARCHIVED.value,Casebook.LifeCycle.PUBLISHED.value):False,
            (Casebook.LifeCycle.ARCHIVED.value,Casebook.LifeCycle.REVISING.value):False,
            (Casebook.LifeCycle.ARCHIVED.value,Casebook.LifeCycle.PREVIOUS_SAVE.value):False,

            (Casebook.LifeCycle.PREVIOUS_SAVE.value,Casebook.LifeCycle.PRIVATELY_EDITING.value):False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value,Casebook.LifeCycle.NEWLY_CLONED.value):False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value,Casebook.LifeCycle.DRAFT.value):False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value,Casebook.LifeCycle.PUBLISHED.value):False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value,Casebook.LifeCycle.REVISING.value):False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value,Casebook.LifeCycle.ARCHIVED.value):False,

        }

        return transition_options[(self.state, target_value)]

    def transition_to(self, desired_state):
        target_state = (hasattr(desired_state, 'value') and desired_state.value) or desired_state
        if not self.can_transition_to(target_state):
            raise ValueError("Cannot transition to desired state")
        if target_state == Casebook.LifeCycle.PUBLISHED.value:
            if self.has_draft:
                self.draft.merge_draft()
            elif self.is_draft:
                self.merge_draft()
            else:
                self.state = target_state
                self.save()
        else:
            self.state = target_state
            self.save()

    #Editions
    @property
    def is_current_edition(self):
        return self.common_title is None or self.common_title.current == self

    @property
    def is_outdated(self):
        return not self.is_current_edition

    @property
    def current_edition(self):
        if self.is_current_edition:
            return self
        return self.common_title.current

    # Collaborators
    @property
    def primary_authors(self):
        return set([c.user for c in self.tempcollaborator_set.all() if c.has_attribution and c.user.attribution != 'Anonymous'])

    @property
    def all_collaborators(self):
        return set([c.user for c in self.tempcollaborator_set.all()])

    def has_collaborator(self, user):
        # filter in the client to allow .prefetch_related('contentcollaborator_set__user') to work:
        return any(c.user_id == user.id for c in self.tempcollaborator_set.all() if c.can_edit)

    def add_collaborator(self, user, **collaborator_kwargs):
        collaborator_to_add = TempCollaborator(user=user, casebook_id=self.id, **collaborator_kwargs)
        collaborator_to_add.save()

    def export(self, include_annotations, file_type='docx'):
        """
            Export this node and children as docx, or as html for conversion by pandoc.

            Given:
            >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

            Export uses 5 queries: selecting descendant nodes, and prefetching ContentAnnotation, Case, TextBlock, and Link.
            >>> with assert_num_queries(select=5):
            ...     file_data = full_casebook.export(include_annotations=True)
        """
        # prefetch all child nodes and related data
        children = list(self.contents.prefetch_resources().prefetch_related('annotations')) if type(
            self) is not Resource else None

        # render html
        template_name = 'export/casebook.html'
        html = render_to_string(template_name, {
            'is_export': True,
            'node': self,
            'children': children,
            'include_annotations': include_annotations,
        })
        if file_type == 'html':
            return html

        # convert to docx with pandoc
        with tempfile.NamedTemporaryFile(suffix='.docx') as pandoc_out:
            command = [
                'pandoc',
                '--from', 'html',
                '--to', 'docx',
                '--reference-doc', os.path.join(settings.PANDOC_DIR, 'reference.docx'),
                '--output', pandoc_out.name,
                '--quiet'
            ]
            if type(self) is Casebook:
                command.extend(['--lua-filter', os.path.join(settings.PANDOC_DIR, 'table_of_contents.lua')])
            try:
                response = subprocess.run(command, input=html.encode('utf8'), stderr=subprocess.PIPE,
                                          stdout=subprocess.PIPE)
            except subprocess.CalledProcessError as e:
                raise Exception("Pandoc command failed: %s" % e.stderr[:100])
            if response.stderr:
                raise Exception("Pandoc reported error: %s" % response.stderr[:100])
            return pandoc_out.read()

    @property
    def testing_editor(self):
        """
        Used for testing purposes, return a user that can edit this casebook.
        """
        return TempCollaborator.objects.filter(can_edit=True, casebook=self).prefetch_related('user').first().user

    @property
    def new_casebook(self):
        return self

    def content_tree__load(self):
        ordinal_to_node_map = {}
        top_level_children = []
        for content_node in self.contents.order_by('ordinals').all():
            content_node._content_tree__children = []
            ordinal_to_node_map[content_node.ordinal_string()] = content_node
            parent_ords = [o for o in content_node.ordinals[:-1]]
            parent_key = '.'.join(map(str,parent_ords))
            while parent_key and parent_key not in ordinal_to_node_map:
                parent_ords.pop()
                parent_key = '.'.join(map(str,parent_ords))
            if parent_key:
                parent = ordinal_to_node_map[parent_key]
                # new_ords = parent_ords + [len(parent._content_tree__children)]
                # content_node.ordinals = new_ords
                content_node._content_tree__parent = parent
                parent._content_tree__children.append(content_node)
            else:
                content_node._content_tree__parent = self
                top_level_children.append(content_node)
        self.content_tree__children = top_level_children

    def content_tree__get_descendant(self, ordinals):
        """
            Fetch a node from content_tree__children with the given ordinals.
        """
        node = self
        ordinals = ordinals
        while ordinals:
            node = node.content_tree__children[ordinals.pop(0) - 1]
        return node

    def content_tree__get_next_available_child_ordinals(self):
        """
            If we add a new section or resource as a child to this node,
            what should that node's ordinals be?
        """
        self.content_tree__load()
        return [max([x.ordinals[-1] for x in self.content_tree__children] or [0]) + 1]

    def content_tree__store(self):
        contents = [x for x in self.content_tree__update_ordinals()]
        """
            Update ordinals in the database for any that need to change, based on nodes that have been moved within
            content_tree__children. It is not valid to add nodes from outside, as their tree values will not be populated.
        """
        bulk_update_with_history(contents, ContentNode, ['ordinals'], batch_size=500, default_change_reason="Tree Repair")

    def content_tree__repair(self):
        self.content_tree__load()
        self.content_tree__store()

    def content_tree__update_ordinals(self):
        """
            Recursively fix ordinals for all descendants that have been moved in the content tree, based on their
            current position in content_tree__children. Return an iterator of all descendants that have been updated.

            Given:
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
            >>> casebook.content_tree__load()
            >>> s_1 = casebook.content_tree__get_descendant([1])
            >>> s_2 = casebook.content_tree__get_descendant([2])

            When we move a node, return only nodes with changed ordinals:
            >>> s_2.content_tree__children.insert(0, s_1.content_tree__children.pop(2))  # move r_1_3 from s_1 to beginning of s_2
            >>> assert set(casebook.content_tree__update_ordinals()) == {r_1_3, s_1_4, r_1_4_2, r_1_4_3, r_1_4_1}
        """
        for i, node in enumerate(self.content_tree__children):
            correct_ordinals = [i + 1]
            if node.ordinals != correct_ordinals:
                node.ordinals = correct_ordinals
                yield node
            if node.content_tree__children:
                yield from node.content_tree__update_ordinals()

    def content_tree__move_to(self,arg):
        raise ValueError('Cannot move casebook node')

    @property
    def in_edit_state(self):
        if self.state == '':
            self.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
            self.save()
        return self.state in {Casebook.LifeCycle.NEWLY_CLONED.value,
                              Casebook.LifeCycle.DRAFT.value,
                              Casebook.LifeCycle.PRIVATELY_EDITING.value}

    @property
    def casebook_color_indicator(self):
        return {
            Casebook.LifeCycle.PRIVATELY_EDITING.value: 'casebook-draft',
            Casebook.LifeCycle.NEWLY_CLONED.value: 'casebook-draft',
            Casebook.LifeCycle.DRAFT.value: 'casebook-draft',
            Casebook.LifeCycle.PUBLISHED.value: 'casebook-public casebook-preview',
            Casebook.LifeCycle.ARCHIVED.value: 'casebook-archived',
            Casebook.LifeCycle.REVISING.value: 'casebook-draft',
            Casebook.LifeCycle.PREVIOUS_SAVE.value: 'casebook-archived'
        }[self.state]

    def tabs_for_user(self, user, current_tab=None):
        read_tab = 'Preview' if self.in_edit_state else 'Casebook'
        if current_tab is None:
            current_tab = read_tab
        tabs = [('Edit', reverse('edit_casebook', args=[self]), self.in_edit_state and self.editable_by(user)),
                (read_tab, reverse('casebook', args=[self]), not self.is_archived),
                ('Credits', reverse('show_credits', args=[self]), not self.is_archived),
                ('Settings', reverse('casebook_settings', args=[self]), self.editable_by(user))]
        return [(n, l, n == current_tab) for n,l,c in tabs if c]

    @property
    def revising(self):
        return self.draft_of


class SectionManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset()

class Section(CasebookAndSectionMixin, SectionAndResourceMixin, ContentNode):
    class Meta:
        proxy = True

    objects = SectionManager()

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse('section', args=[self.new_casebook, self])

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse('edit_section', args=[self.new_casebook, self])

    @property
    def children(self):
        return self._content_tree__children
        # first_ordinals = "ordinals__0_{}".format(len(self.ordinals))
        # return ContentNode.objects.filter(**{
        #     "casebook_id": self.casebook_id,
        #     first_ordinals: self.ordinals,
        #     "ordinals__len": len(self.ordinals) + 1
        # })

    @property
    def primary_authors(self):
        return self.new_casebook.primary_authors

class ResourceManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(new_casebook__isnull=False, resource_id__isnull=False)


class Resource(SectionAndResourceMixin, ContentNode):
    class Meta:
        proxy = True

    objects = ResourceManager()

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse('resource', args=[self.new_casebook, self])

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse('edit_resource', args=[self.new_casebook, self])

    def get_edit_or_absolute_url(self, editing=False):
        """
        See ContentNode.get_edit_or_absolute_url
        In the Rails app, when editing a casebook/section/resource,
        breadcrumbs and TOC entries generally point to the "annotate" view,
        when available. Recreate that here.
        """
        if editing:
            if self.annotatable:
                return self.get_annotate_url()
            return self.get_edit_url()
        return self.get_absolute_url()


    @property
    def annotatable(self):
        """
        Only particular kinds of resources can be annotated.
        """
        return self.type == 'resource' and self.resource_type in ['Case', 'TextBlock']

    def get_annotate_url(self):
        """
        If a resource can be annotated, returns the URL for the page an author
        uses to make annotations. Otherwise, returns a ValueError.
        """
        if self.annotatable:
            return reverse('annotate_resource', args=[self.new_casebook, self])
        raise ValueError('Only Resources (Case and TextBlock) can be annotated.')

    @property
    def originating_authors(self):
        if not self.provenance:
            return set()
        originating_node = set(self.provenance)
        users = [collaborator.user for cn in
                    ContentNode.objects.filter(id__in=originating_node)
                        .select_related('new_casebook')
                        .prefetch_related('new_casebook__tempcollaborator_set__user')
                        .all()
                    for collaborator in cn.new_casebook.tempcollaborator_set.all() if collaborator.has_attribution and collaborator.user.attribution != 'Anonymous']
        return set(users)

    @property
    def primary_authors(self):
        return self.new_casebook.primary_authors

    @property
    def attributed_authors(self):
        return self.primary_authors.union(self.originating_authors)

    @property
    def has_non_current_authors(self):
        return len(self.non_current_authors) > 0

    @property
    def non_current_authors(self):
        ogs = self.originating_authors
        cgs = self.primary_authors
        return ogs.difference(cgs)


#
# End ContentNode Proxies
#

class Link(NullableTimestampedModel):
    name = models.CharField(max_length=1024, blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    url = models.URLField(max_length=1024)
    public = models.BooleanField(null=True, default=True)
    content_type = models.CharField(max_length=255, blank=True, null=True)
    history = HistoricalRecords()

    def get_name(self):
        return self.name if self.name else "Link to {}".format(urlparse(self.url).netloc)

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Link')


class RawContent(TimestampedModel, BigPkModel):
    """Legacy table: https://github.com/harvard-lil/h2o/issues/1044"""
    content = models.TextField(blank=True, null=True)
    source_type = models.CharField(max_length=50, blank=True, null=True)
    source_id = models.BigIntegerField(blank=True, null=True)

    class Meta:
        unique_together = (('source_type', 'source_id'),)


class TextBlock(NullableTimestampedModel, AnnotatedModel):
    name = models.CharField(max_length=255)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    content = models.CharField(max_length=5242880, blank=True, null=False, default="")
    public = models.BooleanField(default=True, blank=True, null=True)
    created_via_import = models.BooleanField(default=False)
    history = HistoricalRecords()

    class Meta:
        indexes = [
            models.Index(fields=['created_at']),
            models.Index(fields=['name']),
            models.Index(fields=['updated_at']),
        ]

    def get_name(self):
        """For consistency, expose name via this method, which is exposed by Link and Case objects"""
        return self.name

    def save(self, *args, **kwargs):
        r"""
            Override save to include the cleanup of user-supplied HTML and the
            repositioning of existing annotations when TextBlock content is changed.

            Given:
            >>> annotations_factory, caplog = [getfixture(f) for f in ['annotations_factory', 'caplog']]
            >>> html_with_annotations =     '<p>\n  <em>[note]Keep foo[/note] [highlight]delete bar[/highlight] [elide]keep baz[/elide] buzz</em>\n</p>'
            >>> new_html =                  '<p>Prepended</p>\n\n<p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\n</p>'
            >>> new_textblock_html_with_annotations = '<p>Prepended</p><p>\n  <em>[note]Keep foo[/note] [elide]keep baz[/elide] buzz add boo</em>\n</p>'

            On save, TextBlock HTML is cleansed and annotations are updated afterwards:
            >>> _, textblock = annotations_factory('TextBlock', html_with_annotations)
            >>> textblock.resource.content = new_html
            >>> with caplog.at_level(logging.DEBUG):
            ...     textblock.resource.save()
            >>> assert dump_annotated_text(textblock) == new_textblock_html_with_annotations
            >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in TextBlock content'
            >>> assert caplog.record_tuples[1][2] == 'Sanitizing TextBlock content'
            >>> assert caplog.record_tuples[2][2] == 'Stripping trailing whitespace in TextBlock content'
            >>> assert caplog.record_tuples[3][2] == 'Updating annotations for TextBlock'
        """
        cleanse_html_field(self, 'content', True)
        super().save(*args, **kwargs)

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='TextBlock')

def validate_unused_prefix(value):
    if value.lower() in set(['accounts',
                     'archived',
                     'casebook',
                     'casebooks',
                     'cases',
                     'pages',
                     'resources',
                     'robots.txt',
                     'sections',
                     'users',
                     'api',
                     'about',
                     'privacy-policy',
                     'terms-of-service',
                     'faq',
                     'search']):
        raise ValidationError('{} is already in use'.format(value))



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
        return User.objects.filter(tempcollaborator__casebook__tempcollaborator__user=self)


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


#
# Legacy Tables: do these contain images and other assets that are referenced
# in casebooks, that COULD be displayed if we migrate properly? Keeping them
# pending study.
# https://github.com/harvard-lil/h2o/issues/1039
#

class CkeditorAsset(models.Model):
    data_file_name = models.CharField(max_length=255)
    data_content_type = models.CharField(max_length=255, blank=True, null=True)
    data_file_size = models.IntegerField(blank=True, null=True)
    assetable_id = models.IntegerField(blank=True, null=True)
    assetable_type = models.CharField(max_length=30, blank=True, null=True)
    type = models.CharField(max_length=30, blank=True, null=True)
    width = models.IntegerField(blank=True, null=True)
    height = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'ckeditor_assets'
        indexes = [
            models.Index(fields=['assetable_type', 'assetable_id']),
            models.Index(fields=['assetable_type', 'type', 'assetable_id']),
        ]


class ContentImage(models.Model):
    name = models.CharField(max_length=255, blank=True, null=True)
    page_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    image_file_name = models.CharField(max_length=255, blank=True, null=True)
    image_content_type = models.CharField(max_length=255, blank=True, null=True)
    image_file_size = models.IntegerField(blank=True, null=True)
    image_updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'content_images'


class MediaType(models.Model):
    label = models.CharField(max_length=255, blank=True, null=True)
    slug = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'media_types'


class Media(models.Model):
    name = models.CharField(max_length=255, blank=True, null=True)
    content = models.TextField(blank=True, null=True)
    media_type_id = models.IntegerField(blank=True, null=True)
    public = models.BooleanField(blank=True, null=True, default=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    user_id = models.IntegerField(default=0)
    created_via_import = models.BooleanField(default=False)

    class Meta:
        db_table = 'medias'



class EmailWhitelist(models.Model):
    university_name = models.CharField(max_length=255, blank=True, null=True)
    university_url = models.URLField(max_length=1024)
    email_domain = models.CharField(max_length=255, blank=True, null=True)
