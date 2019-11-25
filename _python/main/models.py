import os
import re
import subprocess
import tempfile
from os.path import commonprefix
from urllib.parse import urlparse

from django.conf import settings
from django.contrib.auth.models import AnonymousUser
from django.contrib.postgres.fields import JSONField, ArrayField
from django.contrib.postgres.indexes import GinIndex
from django.db import models, transaction
from django.db.models import Q, Prefetch
from django.template.defaultfilters import truncatechars
from django.template.loader import render_to_string
from django.urls import reverse
from django.utils.functional import cached_property
from django.utils.html import format_html
from django.utils.safestring import mark_safe
from django.utils.text import slugify
import lxml.etree
import lxml.sax
from pyquery import PyQuery
from pytest import raises

from .differ import AnnotationUpdater
from test.test_helpers import dump_casebook_outline, dump_content_tree, dump_annotated_text, dump_content_tree_children
from pytest import raises as assert_raises

from .utils import clone_model_instance, fix_after_rails, sanitize, fix_before_deploy, parse_html_fragment, \
    remove_empty_tags, inner_html, block_level_elements, void_elements


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


class SanitizingMixin(object):
    """
    Removes dangerous HTML from a TextField before it is saved to the database.
    See https://docs.djangoproject.com/en/2.2/howto/custom-model-fields/#preprocessing-values-before-saving
    and https://docs.djangoproject.com/en/2.2/ref/models/fields/#django.db.models.Field.pre_save
    """

    def pre_save(self, model_instance, add):
        # TODO:
        # Rails checks to see if the value has changed first;
        # I don't know of a clean and reliable way to do this in Django.
        # Do we need to avoid sanitizing redundantly? In Django, I believe
        # this is handled at the Form level; do we need Model level checks too?
        value = getattr(model_instance, self.attname)
        if value:
            value = sanitize(value)
            setattr(model_instance, self.attname, value)
        return value


class SanitizingCharField(SanitizingMixin, models.TextField):
    pass

class SanitizingTextField(SanitizingMixin, models.TextField):
    pass


# Internal

class ArInternalMetadata(TimestampedModel):
    key = models.CharField(primary_key=True, max_length=255)
    value = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'ar_internal_metadata'


class SchemaMigration(models.Model):
    version = models.CharField(primary_key=True, max_length=255)

    class Meta:
        # managed = False
        db_table = 'schema_migrations'


class Session(NullableTimestampedModel):
    session_id = models.CharField(max_length=255)
    data = models.TextField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'sessions'
        indexes = [
            models.Index(fields=['session_id']),
            models.Index(fields=['updated_at'])
        ]


# Application

class CaseCourt(NullableTimestampedModel):
    name_abbreviation = models.CharField(max_length=150, blank=True, null=True)
    name = models.CharField(max_length=500, blank=True, null=True)
    capapi_id = models.IntegerField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'case_courts'
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['name_abbreviation'])
        ]


class AnnotatedModel(EditTrackedModel):
    r"""
        Abstract base class for Case and TextBlock resource types, which can be annotated. Ensures that annotation
        offsets will be updated when the text contents of this resource are modified.

        Given:
        >>> annotations_factory, *_ = [getfixture(f) for f in ['annotations_factory']]
        >>> html_with_annotations =     '<p>\n  <em>[note]Keep foo[/note] [highlight]delete bar[/highlight] [elide]keep baz[/elide] buzz</em>\n</p>'
        >>> new_html =                  '<p>\n  <em>Keep foo keep baz buzz add boo</em>\n</p>'
        >>> new_html_with_annotations = '<p>\n  <em>[note]Keep foo[/note] [elide]keep baz[/elide] buzz add boo</em>\n</p>'

        Case and TextBlock annotations are updated on save:
        >>> for resource_type in ('Case', 'TextBlock'):
        ...     casebook, case_or_textblock = annotations_factory(resource_type, html_with_annotations)
        ...     case_or_textblock.resource.content = new_html
        ...     case_or_textblock.resource.save()
        ...     assert dump_annotated_text(case_or_textblock) == new_html_with_annotations
    """
    class Meta:
        abstract = True

    tracked_fields = ['content']

    def related_annotations(self):
        return ContentAnnotation.objects.filter(resource__resource_id=self.id, resource__resource_type=self.__class__.__name__, global_start_offset__gte=0)

    def save(self, *args, **kwargs):
        if self.pk and self.has_changed('content'):
            ContentAnnotation.update_annotations(self.related_annotations(), self.original_state['content'], self.content)
        super().save(*args, **kwargs)


class Case(NullableTimestampedModel, AnnotatedModel):
    name_abbreviation = models.CharField(max_length=150)
    name = models.CharField(max_length=10000, blank=True, null=True)
    decision_date = models.DateField(blank=True, null=True)
    public = models.BooleanField(default=False, blank=True, null=True)
    created_via_import = models.BooleanField(default=False)
    capapi_id = models.IntegerField(blank=True, null=True)
    attorneys = JSONField(blank=True, null=True)
    parties = JSONField(blank=True, null=True)  # TODO: this should be deleted. It's just the `name` field with uncorrected typos.
    opinions = JSONField(blank=True, null=True)
    citations = JSONField(blank=True, null=True)
    docket_number = models.CharField(max_length=20000, blank=True, null=True)
    header_html = models.CharField(max_length=15360, blank=True, null=True)  # TODO: no longer used? delete?
    content = models.CharField(max_length=5242880)
    annotations_count = models.IntegerField(default=0, blank=True, null=True)

    case_court = models.ForeignKey(
        'CaseCourt',
        models.PROTECT,
        related_name='cases',
        blank=True,
        null=True,
        db_index = False,
        db_constraint=False
    )

    class Meta:
        # managed = False
        db_table = 'cases'
        indexes = [
            models.Index(fields=['case_court']),
            GinIndex(fields=['citations']),
            models.Index(fields=['created_at']),
            models.Index(fields=['decision_date']),
            models.Index(fields=['name_abbreviation']),
            models.Index(fields=['public']),
            models.Index(fields=['updated_at'])
        ]

    def get_name(self):
        return self.name_abbreviation if self.name_abbreviation else self.name

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Case')


class ContentAnnotation(TimestampedModel, BigPkModel):
    # NOTE: In the Rails app, paragraph-based offsets are always still calculated,
    # to smooth the transition to document-based offsets. We are not recreating that here.
    start_paragraph = models.IntegerField(blank=True, null=True)
    end_paragraph = models.IntegerField(blank=True, null=True)
    start_offset = models.IntegerField(blank=True, null=True)
    end_offset = models.IntegerField(blank=True, null=True)
    kind = models.CharField(max_length=255, choices=(('replace', 'replace'), ('highlight', 'highlight'), ('elide', 'elide'), ('note', 'note'), ('link', 'link')))
    content = models.TextField(blank=True, null=True)  #TODO: validation for URLs
    global_start_offset = models.IntegerField(blank=True, null=True)
    global_end_offset = models.IntegerField(blank=True, null=True)

    resource = models.ForeignKey(
        'Resource',
        on_delete=models.CASCADE,
        related_name='annotations',
    )

    class Meta:
        # managed = False
        db_table = 'content_annotations'
        indexes = [
            models.Index(fields=['resource', 'start_paragraph'])
        ]
        # annotations return in document order, with id to ensure sort stability
        ordering = ['global_start_offset', 'id']

    def __str__(self):
        return "%s %s-%s%s" % (self.kind, self.global_start_offset, self.global_end_offset, " with %s" % truncatechars(self.content, 20) if self.content else "")

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
            fix_before_deploy("Do different annotation types need different handling?")
            if new_start == new_end:
                new_start = new_end = -1

            # apply changes
            annotation.global_start_offset = new_start
            annotation.global_end_offset = new_end
            to_update.append(annotation)

        # save all changes
        if to_update:
            ContentAnnotation.objects.bulk_update(to_update, ['global_start_offset', 'global_end_offset'])


class ContentCollaborator(TimestampedModel, BigPkModel):
    has_attribution = models.BooleanField(default=False)
    role = models.CharField(
        max_length=255,
        choices = (('owner', 'owner'), ('editor', 'editor')),
        blank=True,
        null=True
    )
    user = models.ForeignKey('User',
        on_delete=models.CASCADE,
        blank=True,
        null=True,
        db_constraint=False
    )
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete unneeded ContentCollaborator rows in the Casebook.delete method.
    content = models.ForeignKey(
        'ContentNode',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True
    )

    class Meta:
        # managed = False
        db_table = 'content_collaborators'
        unique_together = (('user', 'content'),)


class ContentNodeQueryset(models.QuerySet):
    """
        This queryset allows us to do ContentNode.objects.prefetch_resources() so that fetched content nodes will
        efficiently have their content_node.resource attribute pre-populated, using a total of three queries instead
        of one query per instance. This is based on the implementation of prefetch_related().

        Given:
        >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]
        >>> section = Section.objects.filter(casebook=full_casebook).first()

        Fetching all resources normally will take a linear number of queries -- each c.resource hits the DB:
        >>> with assert_num_queries(select=7):
        ...     resources = [c.resource for c in section.contents.all() if isinstance(c, Resource)]

        We can reduce to a constant number of queries -- 1 each to fetch Case, TextBlock, and Default items:
        >>> with assert_num_queries(select=4):
        ...     resources = [c.resource for c in section.contents.prefetch_resources() if isinstance(c, Resource)]

        Custom querysets for the Case, TextBlock, and Default items can be provided to further reduce queries:
        >>> with assert_num_queries(select=4):
        ...     resources = [c.resource for c in section.contents.prefetch_resources(case_query=Case.objects.select_related('case_court')) if isinstance(c, Resource)]
        ...     courts = [c.case_court for c in resources if type(c) == Case]
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
            Do the actual work: get IDs for all items in _result_cache, prefetch related Case/TextBlock/Default objects,
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
                link_query = Default.objects.all()
            resources = {}
            for resource_type, query in (('Case', case_query), ('TextBlock', textblock_query), ('Default', link_query)):
                for obj in query.filter(id__in=[obj.resource_id for obj in self._result_cache if obj.resource_type == resource_type]):
                    resources[(resource_type, obj.id)] = obj
            for content_node in self._result_cache:
                if content_node.resource_id:
                    content_node._resource = resources.get((content_node.resource_type, content_node.resource_id))
                    content_node._resource_prefetched = True

    def prefetch_draft(self):
        """ Populate the _drafts queryset so it can be read by casebook.draft """
        return self.prefetch_related(Prefetch('clones', Casebook.objects.filter(draft_mode_of_published_casebook=True), '_drafts'))


class ContentNode(TimestampedModel, BigPkModel):
    title = models.CharField(max_length=10000, blank=True, null=True)
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = SanitizingTextField(blank=True, null=True)
    raw_headnote = models.TextField(blank=True, null=True)
    copy_of = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='clones',
    )

    # casebooks only
    public = models.BooleanField(default=False)
    cloneable = models.BooleanField(default=True)
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True, help_text='Unknown (None) or True; never False')
    ancestry = models.CharField(max_length=255, blank=True, null=True, help_text="List of parent IDs in tree, separated by slashes.")
    # Root user is sometimes used to calculate the "original author" of a book
    # However, it appears that in the modern application, it is not populated when creating new clones.
    # Can we migrate this data so that ancestry + collaborator lookups can always be used instead?
    # Or, shall we always populate this, for the ease in looking up?
    root_user = models.ForeignKey(
        'User',
        blank=True,
        null=True,
        on_delete=models.PROTECT,
        related_name='casebooks_and_clones',
        db_index=False,
        db_constraint=False
    )
    collaborators = models.ManyToManyField('User',
        through='ContentCollaborator',
        related_name='casebooks'
    )

    # sections and resources only
    ordinals = ArrayField(models.IntegerField(), default=list)
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete Casebook contents in the Casebook.delete method.
    casebook = models.ForeignKey(
        'Casebook',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name='contents'
    )

    # resources only
    # These fields define a relationship with a Case, Default, or Textblock
    # not yet described/available via the Django ORM
    resource_type = models.CharField(max_length=255, blank=True, null=True)
    resource_id = models.BigIntegerField(blank=True, null=True)

    # legacy fields, I believe
    is_alias = models.BooleanField(blank=True, null=True)
    playlist_id = models.BigIntegerField(blank=True, null=True)
    slug = models.CharField(max_length=10000, blank=True, null=True)

    objects = ContentNodeQueryset.as_manager()

    class Meta:
        # managed = False
        db_table = 'content_nodes'
        indexes = [
            models.Index(fields=['ancestry']),
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
            >>> resource = resource_factory(casebook=casebook, resource_type='Case', resource_id=case_factory().id)

            ContentNode queries return the appropriate proxy models:
            >>> assert type(ContentNode.objects.get(id=casebook.id)) is Casebook
            >>> assert type(ContentNode.objects.get(id=section.id)) is Section
            >>> assert type(ContentNode.objects.get(id=resource.id)) is Resource
        """
        values_dict = dict(zip(field_names, values))
        if not values_dict['casebook_id']:
            subclass = Casebook
        elif not values_dict['resource_id']:
            subclass = Section
        else:
            subclass = Resource
        return models.Model.from_db.__func__(subclass, db, field_names, values)

    ##
    # Methods common to all ContentNodes
    ##

    def get_slug(self):
        return slugify(self.get_title())

    @property
    def is_private(self):
        return not self.is_public

    def viewable_by(self, user):
        return self.is_public or self.editable_by(user)

    def directly_editable_by(self, user):
        """
        Allow a user to make real-time changes (e.g., via edit view),
        rather than requiring them to make changes via the draft mechanism.
        (See allows_draft_creation_by for more discussion of editing and drafts.)
        """
        return self.is_private and self.editable_by(user)

    def __str__(self):
        return "{} ({})".format(self.get_title(), self.id)

    @property
    def type(self):
        # TODO: In use in templates and tests; shouldn't be necessary. Consider refactoring.
        return type(self).__name__.lower()

    def export(self, include_annotations, file_type='docx'):
        """
            Export this node and children as docx, or as html for conversion by pandoc.

            Given:
            >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

            Export uses 5 queries: selecting descendent nodes, and prefetching ContentAnnotation, Case, TextBlock, and Default.
            >>> with assert_num_queries(select=5):
            ...     file_data = full_casebook.export(include_annotations=True)
        """
        # prefetch all child nodes and related data
        children = list(self.contents.prefetch_resources().prefetch_related('annotations')) if type(self) is not Resource else None

        # render html
        template_name = {Casebook: 'export/casebook.html', Section: 'export/section.html', Resource: 'export/node.html'}[type(self)]
        html = render_to_string(template_name, {
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
                '--docx-preserve-style',
                '--output', pandoc_out.name,
                '--quiet'
            ]
            if type(self) is Casebook:
                command.extend(['--lua-filter', os.path.join(settings.PANDOC_DIR, 'table_of_contents.lua')])
            try:
                response = subprocess.run(command, input=html.encode('utf8'), stderr=subprocess.PIPE, stdout=subprocess.PIPE)
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

    ##
    # About ContentNode Trees:
    # ContentNodes are part of two separate trees: the "content tree", indicating where the node is in the table of
    # contents, and the "version tree", indicating the node's lineage in other casebooks (clones and drafts).
    #
    # The content tree is stored in the `ordinals` field as a postgres array of 1-indexed integers. The root is `[]`,
    # the first child is `[1]`, the first sub-child is `[1,1]` and so on.
    #
    # The version tree is stored in the `ancestry` field as a slash-separated string of IDs. The root is "", the first
    # child is "<parent.id>", the first sub-child is "<parent.id>/<sub_parent.id>", and so on.
    # This is a partial port of https://github.com/stefankroes/ancestry/blob/master/lib/ancestry/materialized_path.rb
    #
    # Because it is confusing to have two database trees with different formats as well as a hierarchy of proxy models,
    # we make two stylistic choices:
    #  (1) All tree methods should be prefixed with "content_tree__" or "version_tree__"
    #  (2) All tree methods should be in a single block in ContentNode instead of on Casebook/Session/Resource subclasses.
    ##

    fix_after_rails("The hand-rolled database trees should be replaced with a Django tree library")

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
        return prefix + [len(self.content_tree__children) + 1]

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
            >>> with assert_num_queries(select=2, update=1):
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
            >>> with raises(ValueError, match='Cannot move casebook node'):
            ...     casebook.content_tree__move_to([2])
            >>> with raises(ValueError, match='Cannot move node to root'):
            ...     s_1.content_tree__move_to([])
            >>> with raises(ValueError, match='Cannot add descendent of Resource'):
            ...     r_1_4_2.content_tree__move_to([1, 1, 1])
            >>> with raises(ValueError, match='Cannot move a node inside itself'):
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
            new_parent = common_parent_node.content_tree__get_descendent(new_ordinals[:-1])
        except IndexError:
            raise ValueError("Invalid new ordinals; parent does not exist: %s" % new_ordinals)
        if type(new_parent) == Resource:
            raise ValueError('Cannot add descendent of Resource')

        # remove node from existing location
        # (look up the location, instead of using self, so we have the copy where content_tree is populated)
        moved_node = common_parent_node.content_tree__get_descendent(old_ordinals)
        if moved_node != self:
            raise ValueError("Unexpected element found at ordinal %s" % old_ordinals)
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

            >>> with assert_num_queries(select=1, update=1):
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

    def content_tree__load(self):
        """
            Fetch all descendents of this node and populate their content_tree__parent and content_tree__children
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
        for node in [self] + list(self.contents.all()):
            if last_child and node.content_tree__is_descendent_of(last_child):
                parents.append(parent)
                parent = last_child
            elif parent:
                while not node.content_tree__is_descendent_of(parent):
                    parent = parents.pop()
            node._content_tree__parent = parent
            node._content_tree__children = []
            if parent:
                parent._content_tree__children.append(node)
            last_child = node

    ## content tree: storing updates

    def content_tree__store(self):
        """
            Update ordinals in the database for any that need to change, based on nodes that have been moved within
            content_tree__children. It is not valid to add nodes from outside, as their tree values will not be populated.

            [self] is included because we don't know whether self.ordinals has changed or not.
        """
        ContentNode.objects.bulk_update([self] + list(self.content_tree__update_ordinals()), ['ordinals'])

    def content_tree__update_ordinals(self):
        """
            Recursively fix ordinals for all descendents that have been moved in the content tree, based on their
            current position in content_tree__children. Return an iterator of all descendents that have been updated.

            Given:
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
            >>> casebook.content_tree__load()
            >>> s_1 = casebook.content_tree__get_descendent([1])
            >>> s_2 = casebook.content_tree__get_descendent([2])

            When we move a node, return only nodes with changed ordinals:
            >>> s_2.content_tree__children.insert(0, s_1.content_tree__children.pop(2))  # move r_1_3 from s_1 to beginning of s_2
            >>> assert set(casebook.content_tree__update_ordinals()) == {r_1_3, s_1_4, r_1_4_2, r_1_4_3, r_1_4_1}
        """
        for i, node in enumerate(self.content_tree__children):
            correct_ordinals = self.ordinals + [i+1]
            if node.ordinals != correct_ordinals:
                node.ordinals = correct_ordinals
                yield node
            if node.content_tree__children:
                yield from node.content_tree__update_ordinals()

    ## content tree: helper functions

    def content_tree__is_descendent_of(self, parent):
        """
            True if ordinals make self a content_tree descendent of parent.
            (This assumes we already know that the nodes are part of the same tree.)
            >>> assert Section(ordinals=[1,1]).content_tree__is_descendent_of(Section(ordinals=[1]))
            >>> assert Resource(ordinals=[1,2,3]).content_tree__is_descendent_of(Section(ordinals=[1]))
            >>> assert not Casebook().content_tree__is_descendent_of(Section(ordinals=[1]))
        """
        return False if type(self) is Casebook else self.ordinals[:len(parent.ordinals)] == parent.ordinals

    def content_tree__get_same_tree_node_from_ordinals(self, ordinals):
        """ Fetch a node from the database, with the given ordinals, that is part of the same tree as self. """
        casebook_id = self.id if type(self) == Casebook else self.casebook_id
        return ContentNode.objects.get(ordinals=ordinals, casebook_id=casebook_id) if ordinals else Casebook.objects.get(id=casebook_id)

    def content_tree__get_descendent(self, ordinals):
        """
            Fetch a node from content_tree__children with the given ordinals.
        """
        if ordinals[:len(self.ordinals)] != self.ordinals:
            raise ValueError("Ordinal value is not a descendent of self")
        node = self
        ordinals = ordinals[len(self.ordinals):]
        while ordinals:
            node = node.content_tree__children[ordinals.pop(0) - 1]
        return node

    ##
    # Version tree methods
    ##

    def version_tree__descendants(self):
        """
            Return all descendants of this node.
            (Used to track the ancestry of casebooks; not used to describe the
            contents of a given casebook.)

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('casebook_tree')
            >>> assert set(root.version_tree__descendants()) == {c_1, c_2, c_1_1, c_1_2}
            >>> assert set(c_1.version_tree__descendants()) == {c_1_1, c_1_2}
            >>> assert set(c_2.version_tree__descendants()) == set()
        """
        child_ancestry = "%s/%s" % (self.ancestry, self.pk) if self.ancestry else str(self.pk)
        return type(self).objects.filter(Q(ancestry=child_ancestry) | Q(ancestry__startswith=child_ancestry+"/"))

    def version_tree__root(self):
        """
            Return root node for this node, or None if no ancestors.
            (Used to track the ancestry of casebooks; not used to describe the
            contents of a given casebook.)

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('casebook_tree')
            >>> assert root.version_tree__root() is None
            >>> assert c_1.version_tree__root() == root
            >>> assert c_1_1.version_tree__root() == root
        """
        if not self.ancestry:
            return None
        return type(self).objects.get(pk=self.ancestry.split("/")[0])

    def version_tree__parent(self):
        """
            Return parent node for this node, or None if no ancestors.
            (Used to track the ancestry of casebooks; not used to describe the
            contents of a given casebook.)

            >>> root, c_1, c_2, c_1_1, c_1_2 = getfixture('casebook_tree')
            >>> assert root.version_tree__parent() is None
            >>> assert c_1.version_tree__parent() == root
            >>> assert c_1_1.version_tree__parent() == c_1
            >>> assert c_2.version_tree__parent() == root
        """
        if not self.ancestry:
            return None
        return type(self).objects.get(pk=self.ancestry.split("/")[-1])

    ##
    # Methods specialized by children
    ##

    def get_title(self):
        """
        Presently, the logic for "What do we call this ContentNode?"
        is pretty complex. We should be able to simplify going forward:
        surely, we can have a single, mandatory DB field, with default
        values supplied via the models. This method is a stop gap, until
        we are free to run migrations on the database.

        This method should be implemented by all children.
        """
        raise NotImplementedError

    @property
    def is_public(self):
        """
        Presently, the `public` field is only accurate on Casebooks:
        the field is `True` for all Sections and Resources.
        This method is a stop gap, as we decide how we'd like to move
        forward with the database field.

        This method should be implemented by all children.
        """
        raise NotImplementedError()

    @property
    def permits_cloning(self):
        """
        Presently, the `cloneable` database field is not in use on the
        Rails side (always True), but according to business logic, not
        all nodes are cloneable. This method is a stop gap, as we decide
        how we'd like to move forward with the database field.

        This method should be implemented by all children.
        """
        raise NotImplementedError()

    def editable_by(self, user):
        """
        Allow a user to alter this node, either directly or via the
        draft mechanism. (See allows_draft_creation_by for more
        discussion of editing and drafts.)

        This method should be implemented by all children.
        """
        raise NotImplementedError()

    @property
    def has_draft(self):
        """
        This node is, or belongs to, a Casebook with a draft. (See
        allows_draft_creation_by for more discussion of drafts.)

        This method should be implemented by all children.
        """
        raise NotImplementedError()

    @property
    def is_or_belongs_to_draft(self):
        """
        This node is, or belongs to, a Casebook that is a draft
        of an already-published Casebook. (See allows_draft_creation_by
        for more discussion of drafts.)

        This method should be implemented by all children.
        """
        raise NotImplementedError()

    def allows_draft_creation_by(self, user):
        """
        Sometimes authors wish to alter a Casebook "in real time", so that
        changes are immediately evident to readers.

        Other times, they prefer to work on a set of edits over time,
        releasing those changes all at once, once they are ready.

        To make this possible, H2O has a mechanism for creating a "draft"
        of a published casebook. In the UI, "private", never-published
        casebooks are often referred to as "drafts"; this is something
        different: a clone of an already-published casebook, private to
        the author, which can be edited at the author's leisure. When the
        author chooses to "publish change", the draft replaces the original.

        You can only have a single draft of a casebook at a time, and you
        can't make drafts of private, never-published casebooks. There's
        no need: you can edit them in real time without affecting readers.)

        This method enforces that logic.

        While drafts are created for entire Casebooks at once, not piecemeal
        for particular Sections or Resources, it proves convenient to have
        access to this method from all ContentNodes.

        This method should be implemented by all children.
        """
        raise NotImplementedError

    def is_annotated(self):
        """
        While only Resources can be annotated, it is useful to know if a
        Casebook or Section contains Resources that have been annotated,
        and it is useful to have a single interface for finding Casebooks,
        Sections, and Resources associated with annotations.

        This method should be implemented by all children.
        """
        raise NotImplementedError

    # URLs

    def get_absolute_url(self):
        """
        Since Casebooks, Sections, and Resources can all be accessed
        from URLs that include slugs AND from urls that omit slugs,
        instruct Django how to calculate the canonical URL for each object.
        https://docs.djangoproject.com/en/2.2/ref/models/instances/#get-absolute-url

        This method should be implemented by all children.
        """
        raise NotImplementedError

    def get_edit_url(self):
        """
        A convenience method, for retrieving the edit URL of a Casebook,
        Section, or Resource without having to specify the view name,
        which is useful in shared templates.

        This method should be implemented by all children.
        """
        raise NotImplementedError

    def get_draft_url(self):
        """
        If this node is or belongs to a Casebook that has a draft, return
        the URL of the draft's "edit" page. Otherwise, return a ValueError.

        This method should be implemented by all children.
        """
        raise NotImplementedError

    def get_edit_or_absolute_url(self, editing=False):
        """
        This is a convenience method, currently used only when building
        the Table of Contents. It probably will no longer be helpful,
        when the editable Table of Contents is rendered via Vue. But
        for now...

        This method should be implemented by all children.
        """
        raise NotImplementedError


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
        to_delete = {Default: [], TextBlock: []}
        for resource in self.contents.prefetch_resources():
            if resource.resource_id and resource.resource_type in ('Default', 'TextBlock'):
                to_delete[type(resource.resource)].append(resource.resource_id)
        for cls, ids in to_delete.items():
            cls.objects.filter(id__in=ids).delete()


class SectionAndResourceMixin(models.Model):
    """
    Methods shared by Sections and Resources
    """
    class Meta:
        abstract = True

    def delete(self, *args, **kwargs):
        """
            Override delete, to ensure the tree is re-ordered afterwards,
            and to clean up now-unused TextBlock and Default/Link resources.

            Given:
            >>> full_casebook_parts_factory, assert_num_queries = [getfixture(i) for i in ['full_casebook_parts_factory','assert_num_queries']]

            # Sections
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = full_casebook_parts_factory()

            Delete a section in a section (and children, including one case, one text block, and one link/default), no reordering required:
            >>> with assert_num_queries(delete=6, select=9, update=1):
            ...     deleted = s_1_4.delete()
            >>> assert deleted == (1, {'main.ContentAnnotation': 0, 'main.Section': 1})
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
            >>> with assert_num_queries(delete=6, select=8, update=1):
            ...     deleted = s_1.delete()
            >>> assert deleted == (1, {'main.ContentAnnotation': 0, 'main.Section': 1})
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
            >>> with assert_num_queries(delete=2, select=3, update=1):
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
            >>> with assert_num_queries(delete=3, select=5, update=1):
            ...     deleted = r_1_4_1.delete()
            >>> assert deleted == (1, {'main.Resource': 1, 'main.ContentAnnotation': 0})
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
            >>> with assert_num_queries(delete=3, select=5, update=1):
            ...     deleted = r_1_4_3.delete()
            >>> assert deleted == (1, {'main.Resource': 1, 'main.ContentAnnotation': 0})
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
            parent = ContentNode.objects.get(casebook=self.casebook, ordinals=ordinals_of_parent)
        else:
            parent = self.casebook

        # Delete this nodes's children, and any related links and textblocks,
        # without recursively calling our custom Section.delete and Resource.delete methods
        # https://docs.djangoproject.com/en/2.2/topics/db/queries/#deleting-objects
        if type(self) is Section:
            self._delete_related_links_and_text_blocks()
            self.contents.delete()
        elif self.resource_type in ['TextBlock', 'Default']:
            self.resource.delete()

        # Delete this node
        return_value = super().delete(*args, **kwargs)

        # Update the ordinals of the content tree
        parent.content_tree__repair()

        return return_value

    @property
    def is_public(self):
        """See ContentNode.is_public"""
        return self.casebook.public

    def editable_by(self, user):
        """See ContentNode.editable_by"""
        return self.casebook.editable_by(user)

    @property
    def permits_cloning(self):
        """See ContentNode.permits_cloning"""
        return not self.casebook.draft_mode_of_published_casebook

    @property
    def has_draft(self):
        """See ContentNode.has_draft"""
        return self.casebook.has_draft

    @property
    def is_or_belongs_to_draft(self):
        """See ContentNode.is_or_belongs_to_draft"""
        return self.casebook.is_or_belongs_to_draft

    def allows_draft_creation_by(self, user):
        """See ContentNode.allows_draft_creation_by"""
        return self.casebook.allows_draft_creation_by(user)

    def get_draft_url(self):
        """See ContentNode.get_draft_url"""
        return self.casebook.get_draft_url()

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
                    casebook_id=self.casebook_id,
                    ordinals=ordinals
                ).get_edit_or_absolute_url(editing)
            })
        return return_value

    @property
    def owner(self):
        """
        This is a convenience method for tests
        """
        return self.casebook.owner


class CasebookManager(models.Manager.from_queryset(ContentNodeQueryset)):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=True)


class Casebook(CasebookAndSectionMixin, ContentNode):
    class Meta:
        proxy = True

    objects = CasebookManager()

    def delete(self, *args, **kwargs):
        """
            Override delete, to ensure that a Casebook is deleted in its entirety.

            Casebook contents and ContentCollaborators would normally be deleted by setting
            Django's `on_delete` attribute to CASCADE, but since we don't want this
            behavior during the deletion of all ContentNode objects, only of Casebooks,
            we have to take care of it manually.

            Similarly, the manual deletion of related Links/Defaults and TextBlocks is due to
            limitations in our current data model, where Resource objects are not
            tied to their related Case/TextBlock/Default objects via foreign keys.

            Given:
            >>> assert_num_queries = getfixture('assert_num_queries')
            >>> nodes = getfixture('full_casebook_parts_with_draft')
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = nodes
            >>> draft = casebook.draft
            >>> assert casebook.contentcollaborator_set.count() == 1

            >>> with assert_num_queries(delete=14, select=15):
            ...     deleted = casebook.delete()
            >>> assert deleted == (1, {'main.ContentAnnotation': 0, 'main.Casebook': 1})
            >>> assert casebook.contentcollaborator_set.count() == 0
            >>> for node in nodes:
            ...     with assert_raises(ContentNode.DoesNotExist):
            ...         node.refresh_from_db()
            >>> with assert_raises(Casebook.DoesNotExist):
            ...     draft.refresh_from_db()
        """
        if self.draft:
            self.draft.delete()
        self._delete_related_links_and_text_blocks()
        self.contents.all().delete()
        self.contentcollaborator_set.all().delete()
        return super().delete(*args, **kwargs)

    @property
    def sections(self):
        return Section.objects.filter(casebook=self)

    @property
    def resources(self):
        return Resource.objects.filter(casebook=self)

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse('casebook', args=[self])

    def get_draft_url(self):
        """See ContentNode.get_draft_url"""
        if self.draft:
            return reverse('edit_casebook', args=[self.draft])
        raise ValueError("This casebook doesn't have a draft.")

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse('edit_casebook', args=[self])

    def get_title(self):
        """See ContentNode.get_title"""
        return self.title or "Untitled casebook"
        # Proposed: I dislike the ID number here
        # return self.title or "Untitled casebook #%s" % self.pk

    @property
    def is_public(self):
        """See ContentNode.is_public"""
        return self.public

    def editable_by(self, user):
        """See ContentNode.editable_by"""
        return user.is_authenticated and (self.has_collaborator(user) or user.is_superadmin)

    @property
    def permits_cloning(self):
        """See ContentNode.permits_cloning"""
        return not self.draft_mode_of_published_casebook

    @property
    def has_draft(self):
        """See ContentNode.has_draft"""
        return self.clones.filter(draft_mode_of_published_casebook=True).exists()

    @property
    def is_or_belongs_to_draft(self):
        """See ContentNode.is_or_belongs_to_draft"""
        return self.draft_mode_of_published_casebook

    def allows_draft_creation_by(self, user):
        """See ContentNode.allows_draft_creation_by"""
        return self.is_public and not self.has_draft and self.editable_by(user)

    @cached_property
    def draft(self):
        """ Return the draft copy of this casebook, if it exists, or else None. """
        if hasattr(self, '_drafts'):
            # populated by Casebook.objects.prefetch_draft()
            return self._drafts[0] if self._drafts else None
        return self.clones.filter(draft_mode_of_published_casebook=True).first()

    @cached_property
    def draft_of(self):
        """ Return the casebook for which this is a draft, if this is a draft, or else None. """
        return self.copy_of if self.draft_mode_of_published_casebook else None

    def make_draft(self):
        """
            Clone casebook in draft mode, copying existing collaborators.

            Given:
            >>> full_casebook, user = [getfixture(i) for i in ['full_casebook', 'user']]
            >>> full_casebook.add_collaborator(user, role='editor')
            >>> draft = full_casebook.make_draft()

            `draft` will be in draft mode and will have the same collaborators as the original:
            >>> assert draft.draft_mode_of_published_casebook is True
            >>> assert (set((c.user, c.role) for c in full_casebook.contentcollaborator_set.all()) ==
            ...         set((c.user, c.role) for c in draft.contentcollaborator_set.all()))
        """
        return self.clone(draft_mode=True)

    @transaction.atomic
    def merge_draft(self):
        """
            Merge draft casebook back into parent, and delete draft.

            Given:
            >>> reset_sequences, full_casebook, assert_num_queries = [getfixture(i) for i in ['reset_sequences', 'full_casebook', 'assert_num_queries']]
            >>> draft = full_casebook.make_draft()
            >>> _ = ContentNode.objects.filter(id=2).update(copy_of_id=1)  # mark node 2 as copy_of node 1

            Merge draft back into original:
            >>> draft.title = "New Title"
            >>> draft.save()
            >>> with assert_num_queries(delete=8, select=11, update=3):
            ...     new_casebook = draft.merge_draft()
            >>> assert new_casebook == full_casebook
            >>> expected = [
            ...     'Casebook<1>: New Title',
            ...     ' Section<12>: Some Section 1',
            ...     '  ContentNode<13> -> TextBlock<3>: Some TextBlock Name 0',
            ...     '  ContentNode<14> -> Case<1>: Foo Foo0 vs. Bar Bar0',
            ...     '   ContentAnnotation<5>: highlight 0-10',
            ...     '   ContentAnnotation<6>: elide 0-10',
            ...     '  ContentNode<15> -> Default<3>: Some Link Name 0',
            ...     '  Section<16>: Some Section 5',
            ...     '   ContentNode<17> -> TextBlock<4>: Some TextBlock Name 1',
            ...     '   ContentNode<18> -> Case<2>: Foo Foo1 vs. Bar Bar1',
            ...     '    ContentAnnotation<7>: note 0-10',
            ...     '    ContentAnnotation<8>: replace 0-10',
            ...     '   ContentNode<19> -> Default<4>: Some Link Name 1',
            ...     ' Section<20>: Some Section 9',
            ... ]
            >>> assert dump_casebook_outline(full_casebook) == expected

            Assets associated with old published version are gone:
            >>> assert set(ContentNode.objects.values_list('id', flat=True)) == {1, 12, 13, 14, 15, 16, 17, 18, 19, 20}
            >>> assert set(ContentAnnotation.objects.values_list('id', flat=True)) == {5, 6, 7, 8}
            >>> assert set(TextBlock.objects.values_list('id', flat=True)) == {3, 4}
            >>> assert set(Default.objects.values_list('id', flat=True)) == {3, 4}

            The original copy_of attributes from the published version are preserved:
            >>> assert ContentNode.objects.get(id=12).copy_of_id == 1
        """
        # set up variables
        draft = self
        parent = self.copy_of
        if not self.draft_mode_of_published_casebook:
            raise ValueError("Only draft casebooks may be merged")

        # update casebook attributes
        for attr in ('headnote', 'title', 'subtitle'):
            setattr(parent, attr, getattr(draft, attr))
        parent.save()

        # delete old links and textblocks
        parent._delete_related_links_and_text_blocks()

        # delete old annotations
        ContentAnnotation.objects.filter(resource__casebook=parent).delete()

        # copy copy_of attribute from old content nodes to new ones
        nodes_to_update = list(draft.contents.select_related('copy_of'))
        for node in nodes_to_update:
            node.copy_of_id = node.copy_of.copy_of_id
        ContentNode.objects.bulk_update(nodes_to_update, ['copy_of_id'])

        # delete old content nodes
        parent.contents.all().delete()

        # move new content nodes
        draft.contents.update(casebook=parent)

        # delete draft
        draft.delete()

        return parent

    @transaction.atomic
    def clone(self, owner=None, draft_mode=False):
        """
            Clone casebook with all of its assets. If User object `owner` is provided, that user will replace the
            existing users. If draft_mode=True, clone will be marked as a draft.

            Given an initial casebook like this:
            >>> reset_sequences, full_casebook, user, assert_num_queries = [getfixture(i) for i in ['reset_sequences', 'full_casebook', 'user', 'assert_num_queries']]
            >>> expected = [
            ...     'Casebook<1>: Some Title 0',
            ...     ' Section<2>: Some Section 1',
            ...     '  ContentNode<3> -> TextBlock<1>: Some TextBlock Name 0',
            ...     '  ContentNode<4> -> Case<1>: Foo Foo0 vs. Bar Bar0',
            ...     '   ContentAnnotation<1>: highlight 0-10',
            ...     '   ContentAnnotation<2>: elide 0-10',
            ...     '  ContentNode<5> -> Default<1>: Some Link Name 0',
            ...     '  Section<6>: Some Section 5',
            ...     '   ContentNode<7> -> TextBlock<2>: Some TextBlock Name 1',
            ...     '   ContentNode<8> -> Case<2>: Foo Foo1 vs. Bar Bar1',
            ...     '    ContentAnnotation<3>: note 0-10',
            ...     '    ContentAnnotation<4>: replace 0-10',
            ...     '   ContentNode<9> -> Default<2>: Some Link Name 1',
            ...     ' Section<10>: Some Section 9',
            ... ]
            >>> assert dump_casebook_outline(full_casebook) == expected
            >>> assert full_casebook.owner != user

            Return a cloned casebook like this:
            >>> with assert_num_queries(select=5, insert=6):
            ...     clone = full_casebook.clone(owner=user)
            >>> expected = [
            ...     'Casebook<11>: Some Title 0',
            ...     ' Section<12>: Some Section 1',
            ...     '  ContentNode<13> -> TextBlock<3>: Some TextBlock Name 0',
            ...     '  ContentNode<14> -> Case<1>: Foo Foo0 vs. Bar Bar0',
            ...     '   ContentAnnotation<5>: highlight 0-10',
            ...     '   ContentAnnotation<6>: elide 0-10',
            ...     '  ContentNode<15> -> Default<3>: Some Link Name 0',
            ...     '  Section<16>: Some Section 5',
            ...     '   ContentNode<17> -> TextBlock<4>: Some TextBlock Name 1',
            ...     '   ContentNode<18> -> Case<2>: Foo Foo1 vs. Bar Bar1',
            ...     '    ContentAnnotation<7>: note 0-10',
            ...     '    ContentAnnotation<8>: replace 0-10',
            ...     '   ContentNode<19> -> Default<4>: Some Link Name 1',
            ...     ' Section<20>: Some Section 9',
            ... ]
            >>> assert dump_casebook_outline(clone) == expected
            >>> assert clone.owner == user
            >>> assert clone.ancestry == str(full_casebook.id)
            >>> clone_of_clone = clone.clone(owner=user)
            >>> assert clone_of_clone.ancestry == "{}/{}".format(full_casebook.id, clone.id)
            >>> clone3 = clone_of_clone.clone(owner=user)
            >>> assert clone3.ancestry == "{}/{}/{}".format(full_casebook.id, clone.id, clone_of_clone.id)
        """
        # clone casebook
        old_casebook = self
        cloned_casebook = clone_model_instance(old_casebook, copy_of=old_casebook, public=False, draft_mode_of_published_casebook=(draft_mode or None))
        if old_casebook.ancestry:
            cloned_casebook.ancestry = "{}/{}".format(old_casebook.ancestry, old_casebook.id)
        else:
            cloned_casebook.ancestry = str(old_casebook.id)
        cloned_casebook.save()

        # clone or replace collaborators
        if owner:
            cloned_casebook.add_collaborator(user=owner, role='owner', has_attribution=True)
        else:
            roles = [clone_model_instance(c, content=cloned_casebook) for c in self.contentcollaborator_set.all()]
            ContentCollaborator.objects.bulk_create(roles)
            owner = next(role.user for role in roles if role.role == 'owner')

        # clone contents
        cloned_resources = {TextBlock: [], Default: []}  # collect new TextBlocks and Defaults for bulk_create
        cloned_content_nodes = []  # collect new ContentNodes for bulk_create
        cloned_annotations = []  # collect new ContentAnnotations for bulk_create
        for old_content_node in old_casebook.contents.prefetch_resources().prefetch_related('annotations'):
            # clone content_node
            cloned_content_node = clone_model_instance(old_content_node, copy_of=old_content_node, casebook=cloned_casebook, is_alias=False)
            # TODO: On rails is_alias is set to True by CloneCasebook.clone_resources (in raw sql), and then set to False
            # TODO: again by CloneCasebook.clone_annotations. I think the field is unused in any application logic.
            # TODO: Prod data has about equal parts True, False, and null in this column.
            # TODO: There doesn't seem to be any rhyme or reason about how it's set.
            # TODO: No casebooks are True. I think we can delete the column, but in the meantime, let's set to False.
            # >>> set(node.type for node in ContentNode.objects.filter(is_alias=True))
            # {'resource', 'section'}
            # >>> set(node.type for node in ContentNode.objects.filter(is_alias=False))
            # {'resource'}
            # >>> set(node.type for node in ContentNode.objects.filter(is_alias=None))
            # {'resource', 'casebook', 'section'}
            cloned_content_nodes.append(cloned_content_node)

            # clone annotations
            for old_annotation in old_content_node.annotations.all():
                cloned_annotation = clone_model_instance(old_annotation)
                cloned_annotations.append((cloned_annotation, cloned_content_node))

            # clone resources
            if old_content_node.resource_id and old_content_node.resource_type != 'Case':
                cloned_resource = clone_model_instance(old_content_node.resource)
                cloned_resource.user = owner
                cloned_resources[type(cloned_resource)].append((cloned_resource, cloned_content_node))

        # save TextBlocks and Defaults
        for resource_class, resources in cloned_resources.items():
            resource_class.objects.bulk_create(r[0] for r in resources)
            # after saving, update the associated cloned_content_nodes to point to the new resource_ids
            for cloned_resource, cloned_content_node in resources:
                cloned_content_node.resource_id = cloned_resource.id

        # save ContentNodes
        ContentNode.objects.bulk_create(cloned_content_nodes)

        # save ContentAnnotations (first update cloned_annotations to point to the new content_node IDs)
        for cloned_annotation, cloned_content_node in cloned_annotations:
            cloned_annotation.resource = cloned_content_node
        ContentAnnotation.objects.bulk_create(r[0] for r in cloned_annotations)

        return cloned_casebook

    # Collaborators

    def root_owner(self):
        """
        Returns the "original author" of a Casebook, when that Casebook
        is a clone, or a clone of a clone, etc.

        TODO: when we can run migrations, we should be able to simplify
        this, so that there is only one technique for all casebooks.
        """
        if self.root_user_id:
            return self.root_user
        elif self.ancestry:
            return self.version_tree__root().owner

    def users_with_role(self, role):
        # filter in the client to allow .prefetch_related('contentcollaborator_set__user') to work:
        return [c.user for c in self.contentcollaborator_set.all() if c.role == role]

    @property
    def attributors(self):
        """
        Users whose authorship should be attributed (to permit the decoupling of attribution and permission levels).

        TODO: should all owners have attribution?
        TODO: should any editors have attribution?
        """
        # filter in the client to allow .prefetch_related('contentcollaborator_set__user') to work:
        return [c.user for c in sorted((c for c in self.contentcollaborator_set.all() if c.has_attribution), key=lambda c: 1 if c.role == 'owner' else 2)]

    @property
    def editors(self):
        # TODO: how are editors and owners different?
        return self.users_with_role('editor')

    @property
    def owners(self):
        return self.users_with_role('owner')

    @property
    def owner(self):
        return self.owners[0]

    def has_collaborator(self, user):
        # filter in the client to allow .prefetch_related('contentcollaborator_set__user') to work:
        return any(c.user_id == user.id for c in self.contentcollaborator_set.all())

    def add_collaborator(self, user, **collaborator_kwargs):
        ContentCollaborator.objects.create(user=user, content=self, **collaborator_kwargs)


class SectionManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=False, resource_id__isnull=True)


class Section(CasebookAndSectionMixin, SectionAndResourceMixin, ContentNode):
    class Meta:
        proxy = True

    objects = SectionManager()

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse('section', args=[self.casebook, self])

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse('edit_section', args=[self.casebook, self])

    def get_title(self):
        """See ContentNode.get_title"""
        return self.title if self.title else "Untitled section"

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
        return ContentNode.objects.filter(**{
            "casebook_id": self.casebook_id,
            first_ordinals: self.ordinals,
            "ordinals__len__gte": len(self.ordinals) + 1
        })


class ResourceManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(casebook__isnull=False, resource_id__isnull=False)


class Resource(SectionAndResourceMixin, ContentNode):
    class Meta:
        proxy = True

    objects = ResourceManager()

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse('resource', args=[self.casebook, self])

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse('edit_resource', args=[self.casebook, self])

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

    def get_title(self):
        """See ContentNode.get_title"""
        if self.title:
            return self.title
        elif self.resource_type == 'Default':
            if self.resource.name:
                return self.resource.name
            else:
                return "Link to {}".format(urlparse(self.resource.url).netloc)
        elif self.resource_type == 'TextBlock':
            return self.resource.name
        elif self.resource_type == 'Case':
            return self.resource.get_name()
        else:
            raise NotImplementedError

    def is_annotated(self):
        """See ContentNode.is_annotated"""
        return bool(self.annotations)

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
        if not self._resource_prefetched:
            if not self.resource_id:
                return None
            if self.resource_type in ['Case', 'TextBlock', 'Default']:
                # so fancy...
                self._resource = globals()[self.resource_type].objects.get(id=self.resource_id)
                self._resource_prefetched = True
            else:
                raise NotImplementedError
        return self._resource

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
            return reverse('annotate_resource', args=[self.casebook, self])
        raise ValueError('Only Resources (Case and TextBlock) can be annotated.')

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
            ...     assert annotated_html == expected_html, "Expected:\n%s\nGot:\n%s" % (expected_html, annotated_html)

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
        """

        # Start with a sorted list of the start and end insertion points for each annotation.
        # Each entry in the list is shaped like (annotation_offset, is_start_tag, annotation):
        annotations = []
        for annotation in self.annotations.all():
            annotations.append((annotation.global_start_offset, True, annotation))
            annotations.append((annotation.global_end_offset, False, annotation))
        annotations.sort(key=lambda a: a[:2])  # sort by first two fields, so we're ordered by offset, then we get end tags and then start tags for a given offset

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
                        self.prev_tag and self.prev_tag[0] == self.out_handler.endElement and self.prev_tag[1] in block_level_elements and
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
                while annotations and (end_offset > annotations[0][0] or (end_offset == annotations[0][0] and not annotations[0][1])):
                    annotation_offset, is_start_tag, annotation = annotations.pop(0)

                    # consume and emit the text that comes before this annotation:
                    if annotation_offset > start_offset:
                        split = annotation_offset-start_offset
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
                            self.out_ops.append((self.out_handler.startElement, 'span', {'custom-style': 'Elision' if kind == 'elide' else 'Replacement Text'}))
                            self.addText(annotation.content or '' if kind == 'replace' else '[ … ]')
                            self.out_ops.append((self.out_handler.endElement, 'span'))
                            self.elide += 1
                        else:
                            self.elide = max(self.elide-1, 0)  # decrement, but no lower than zero

                    else:  # kind == 'link' or 'note' or 'highlight'
                        # link/note/highlight tags require wrapping all subsequent text in <span> tags.
                        # In addition to emitting the open tags themselves, also add the open and close tags to
                        # wrap_before_tags and wrap_after_tags so that every tag we encounter can be wrapped with
                        # close and open tags for all open annotations.
                        if is_start_tag:
                            # get correct open and close tags for this annotation:
                            if kind == 'link':
                                open_tag = (self.out_handler.startElement, 'a', {'href': annotation.content, 'class': 'annotate'})
                                close_tag = (self.out_handler.endElement, 'a')
                            elif kind == 'note':
                                open_tag = (self.out_handler.startElement, 'span', {'class': 'annotate'})
                                close_tag = (self.out_handler.endElement, 'span')
                            elif kind == 'highlight':
                                open_tag = (self.out_handler.startElement, 'span', {'class': 'annotate highlighted', 'custom-style': 'Highlighted Text'})
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
                            self.out_ops.extend(self.wrap_before_tags+self.wrap_after_tags)
                            self.wrap_before_tags.remove(annotation.close_tag)

                            # emit the footnote marker:
                            if kind == 'note' or kind == 'link':
                                self.footnote_index += 1
                                self.out_ops.append((self.out_handler.startElement, 'span', {'custom-style': 'Footnote Reference'}))
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
        source_tree = parse_html_fragment(self.resource.content)
        handler = AnnotationContentHandler()
        lxml.sax.saxify(source_tree, handler)
        dest_tree = handler.get_output_tree()

        # clean up the output tree:
        remove_empty_tags(dest_tree)  # tree may contain empty tags from elide/replace annotations
        self.update_tree_for_export(dest_tree)  # apply general rules that are the same for annotated or un-annotated trees

        return mark_safe(inner_html(dest_tree))

    def footnote_annotations(self):
        return mark_safe("".join(
            format_html('<span custom-style="Footnote Reference">{}</span> {} ', "*" * (i+1), annotation.content)
            for i, annotation in enumerate(a for a in self.annotations.all() if a.kind in ('note', 'link'))
        ))

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


#
# End ContentNode Proxies
#

class Default(NullableTimestampedModel):
    """
    These are actually Link Resource
    """
    name = models.CharField(max_length=1024, blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    url = models.URLField(max_length=1024)
    public = models.BooleanField(null=True, default=True)
    content_type = models.CharField(max_length=255, blank=True, null=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    created_via_import = models.BooleanField(default=False)

    # the person who created the TextBlock. what's the correct on_delete here?
    user = models.ForeignKey('User',
        on_delete=models.PROTECT,
        related_name='defaults',
        blank=True,
        null=True,
        db_index=False,
        db_constraint=False,
        default=0
    )

    class Meta:
        # managed = False
        db_table = 'defaults'

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='Default')


class RawContent(TimestampedModel, BigPkModel):
    content = models.TextField(blank=True, null=True)
    source_type = models.CharField(max_length=50, blank=True, null=True)
    source_id = models.BigIntegerField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'raw_contents'
        unique_together = (('source_type', 'source_id'),)


class Role(NullableTimestampedModel):
    """
        User roles.
    """
    name = models.CharField(max_length=40, blank=True, null=True)
    authorizable_type = models.CharField(max_length=40, blank=True, null=True)
    authorizable_id = models.IntegerField(blank=True, null=True)

    class Meta:
        # managed = False
        db_table = 'roles'
        indexes = [
            models.Index(fields=['name']),
            models.Index(fields=['authorizable_type']),
            models.Index(fields=['authorizable_id']),
        ]

    def __str__(self):
        if self.name == 'asker':
            return "{} ({} {})".format(self.name, self.authorizable_type, self.authorizable_id)
        return self.name


class RolesUser(NullableTimestampedModel, BigPkModel):
    """
        Join table for User and Role.
    """
    user = models.ForeignKey(
        'User',
        blank=True,
        null=True,
        on_delete=models.CASCADE,
        db_constraint=False
    )
    role = models.ForeignKey(
        Role,
        blank=True,
        null=True,
        on_delete=models.CASCADE,
        db_constraint=False
    )

    class Meta:
        # managed = False
        db_table = 'roles_users'


class TextBlock(NullableTimestampedModel, AnnotatedModel):
    name = models.CharField(max_length=255)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    content = SanitizingCharField(max_length=5242880)
    version = models.IntegerField(default=1)
    public = models.BooleanField(default=True, blank=True, null=True)
    created_via_import = models.BooleanField(default=False)
    annotations_count = models.IntegerField(default=0, blank=True, null=True)

    # The person who created the TextBlock.
    # This field doesn't appear to be populated by Rails at present,
    # when creating new TextBlocks...
    # What's the correct "on_delete" behavior? Can we.... delete this whole column?
    user = models.ForeignKey('User',
        blank=True,
        null=True,
        on_delete=models.PROTECT,
        db_index=False,
        db_constraint=False,
        default=0
    )

    # legacy fields, I believe
    enable_feedback = models.BooleanField(default=True)
    enable_discussions = models.BooleanField(default=False)
    enable_responses = models.BooleanField(default=False)

    class Meta:
        # managed = False
        db_table = 'text_blocks'
        indexes = [
            models.Index(fields=['created_at']),
            models.Index(fields=['name']),
            models.Index(fields=['updated_at']),
        ]

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='TextBlock')


class UnpublishedRevision(TimestampedModel, BigPkModel):
    field = models.CharField(max_length=255)
    value = models.CharField(max_length=50000, blank=True, null=True)

    # N.B. in the prod database, these relationships are tracked in Int fields,
    # rather than a BigInt fields, even though these models' primary keys are
    # BigInts. We should consider migrating soon to reconcile this.

    # These foreign keys are marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources.
    # This table is not used by the Django application; we will drop it soon.

    node = models.ForeignKey(
        'ContentNode',
        on_delete=models.DO_NOTHING,
        related_name='revisions',
        help_text='Node in the draft.',
        blank=True,
        null=True,
        db_constraint=False,
        db_index=False
    )
    node_parent = models.ForeignKey(
        'ContentNode',
        on_delete=models.DO_NOTHING,
        related_name='draft_revisions',
        help_text='Corresponding node in the original, published casebook.',
        blank=True,
        null=True,
        db_constraint=False,
        db_index=False
    )
    # I'm not sure why this is stored separately; redundant with node?
    casebook = models.ForeignKey(
        'Casebook',
        on_delete=models.DO_NOTHING,
        related_name='casebook_revisions',
        help_text='The draft casebook.',
        blank=True,
        null=True,
        db_constraint=False,
        db_index=False
    )
    # I'm not sure that this field is in use, presently.
    annotation = models.ForeignKey(
        'ContentAnnotation',
        blank=True,
        null=True,
        on_delete=models.DO_NOTHING,
        db_constraint=False,
        db_index=False
    )

    class Meta:
        # managed = False
        db_table = 'unpublished_revisions'
        indexes = [
            models.Index(fields=['node', 'field'])
        ]


class User(NullableTimestampedModel):
    login = models.CharField(max_length=255, blank=True, null=True)
    email_address = models.CharField(max_length=255, blank=True, null=True, unique=True)
    title = models.CharField(max_length=255, blank=True, null=True)
    attribution = models.CharField(max_length=255, default='Anonymous')
    affiliation = models.CharField(max_length=255, blank=True, null=True)
    verified_email = models.BooleanField(default=False)
    verified_professor = models.BooleanField(default=False)
    professor_verification_requested = models.BooleanField(default=False)

    # used to assign super_admin or case_admin status
    roles = models.ManyToManyField(Role,
        through=RolesUser
    )

    # calculated
    login_count = models.IntegerField(default=0)
    last_request_at = models.DateTimeField(blank=True, null=True)
    last_login_at = models.DateTimeField(blank=True, null=True)
    current_login_at = models.DateTimeField(blank=True, null=True)
    last_login_ip = models.CharField(max_length=255, blank=True, null=True)
    current_login_ip = models.CharField(max_length=255, blank=True, null=True)

    # auth/crypto innards
    crypted_password = models.CharField(max_length=255, blank=True, null=True)
    password_salt = models.CharField(max_length=255, blank=True, null=True)
    persistence_token = models.CharField(max_length=255)
    oauth_token = models.CharField(max_length=255, blank=True, null=True)
    oauth_secret = models.CharField(max_length=255, blank=True, null=True)
    perishable_token = models.CharField(max_length=255, blank=True, null=True)

    # all legacy fields, I believe
    tz_name = models.CharField(max_length=255, blank=True, null=True)
    url = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    canvas_id = models.CharField(max_length=255, blank=True, null=True)
    default_font = models.CharField(max_length=255, blank=True, null=True, default='futura')
    default_font_size = models.CharField(max_length=255, blank=True, null=True, default=10)
    print_titles = models.BooleanField(default=True)
    print_dates_details = models.BooleanField(default=True)
    print_paragraph_numbers = models.BooleanField(default=True)
    print_annotations = models.BooleanField(default=False)
    print_highlights = models.CharField(max_length=255, default='original')
    print_font_face = models.CharField(max_length=255, default='dagny')
    print_font_size = models.CharField(max_length=255, default='small')
    default_show_comments = models.BooleanField(default=False)
    default_show_paragraph_numbers = models.BooleanField(default=True)
    hidden_text_display = models.BooleanField(default=False)
    print_links = models.BooleanField(default=True)
    toc_levels = models.CharField(max_length=255, default='')
    print_export_format = models.CharField(max_length=255, default='')
    image_file_name = models.CharField(max_length=255, blank=True, null=True)
    image_content_type = models.CharField(max_length=255, blank=True, null=True)
    image_file_size = models.IntegerField(blank=True, null=True)
    image_updated_at = models.DateTimeField(blank=True, null=True)

    EMAIL_FIELD = 'email_address'
    USERNAME_FIELD = 'email_address'
    REQUIRED_FIELDS = []  # used by createsuperuser

    class Meta:
        # managed = False
        db_table = 'users'
        indexes = [
            models.Index(fields=['affiliation']),
            models.Index(fields=['attribution']),
            models.Index(fields=['email_address']),
            models.Index(fields=['id']),
            models.Index(fields=['last_request_at']),
            models.Index(fields=['login']),
            models.Index(fields=['oauth_token']),
            models.Index(fields=['persistence_token']),
            models.Index(fields=['tz_name']),
        ]

    @property
    def email_domain(self):
        # TODO! In the meantime, return the full address
        # m = email_address.match /@(.+)$/
        # m.try(:[], 1) || '?.edu'
        return self.email_address

    @property
    def anonymous_name(self):
        return "{}#{}".format(self.email_domain, self.id)

    @property
    def display_name(self):
        """
            In rails this is also known as "display" and "simple_display"
        """
        if self.attribution:
            return self.attribution
        elif self.title:
            return self.title
        return self.anonymous_name

    # TODO: are all users with verified email addresses active,
    # or is there another category of non-active users?
    @property
    def is_active(self):
        return self.verified_email

    def has_role(self, role):
        return self.roles.filter(name=role).exists()

    @cached_property
    def is_superadmin(self):
        return self.has_role('superadmin')

    @property
    def is_staff(self):
        return self.is_superadmin

    # methods replicating Django's PermissionsMixin,
    # necessary for the Django admin to work
    # https://docs.djangoproject.com/en/2.2/topics/auth/customizing/#custom-users-and-permissions

    @property
    def is_superuser(self):
        return self.is_superadmin

    def has_perm(self, perm, obj=None):
        return self.is_superuser

    def has_module_perms(self, app_label):
        return self.is_superuser

    # differentiate between real User model and AnonymousUser model:
    is_authenticated = True
    is_anonymous = False

    def __str__(self):
        return self.display_name

    def non_draft_casebooks(self):
        """
            Casebooks, published or not, but excluding draft copies.
            Drafts of published casebooks should not show up on their own, but inline with the published casebook.
            Equivalent of Rails "owned_casebook_compacted"

            Includes all casebooks the user is a collaborator on, regardless of role.
        """
        return self.casebooks.filter(draft_mode_of_published_casebook=None)

    def published_casebooks(self):
        """
            Public casebooks owned by this user.
            Equivalent of Rails "user.owned.published"

            Currently only includes casebooks the user owns.
        """
        # TBD: This probably wants to be:
        # return self.casebooks.filter(contentcollaborator__has_attribution=True, public=True)
        # TBD: We probably need some guarantee that drafts aren't public.
        return self.casebooks.filter(contentcollaborator__role='owner', public=True)


# make AnonymousUser API conform with User API
AnonymousUser.is_superadmin = False


#
# Legacy Tables
#

class UserCollection(models.Model):
    user_id = models.IntegerField(blank=True, null=True)
    name = models.CharField(max_length=255, blank=True, null=True)
    description = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'user_collections'


class UserCollectionsUser(models.Model):
    # NB: This table does not have a primary key in production,
    # which Django can't deal with, and cannot recreate when instantiating the table
    user_id = models.IntegerField(blank=True, null=True)
    user_collection_id = models.IntegerField(blank=True, null=True)

    class Meta:
        db_table = 'user_collections_users'


class Annotation(models.Model):
    collage_id = models.IntegerField(blank=True, null=True)
    annotation = models.CharField(max_length=10240, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    cloned = models.BooleanField(default=False)
    xpath_start = models.CharField(max_length=255, blank=True, null=True)
    xpath_end = models.CharField(max_length=255, blank=True, null=True)
    start_offset = models.IntegerField(default=0)
    end_offset = models.IntegerField(default=0)
    link = models.CharField(max_length=255, blank=True, null=True)
    hidden = models.BooleanField(default=False)
    highlight_only = models.CharField(max_length=255, blank=True, null=True)
    annotated_item_id = models.IntegerField(default=0)
    annotated_item_type = models.CharField(max_length=255, default="Collage")
    error = models.BooleanField(default=False)
    feedback = models.BooleanField(default=False)
    discussion = models.BooleanField(default=False)
    user_id = models.IntegerField(blank=True, null=True)

    class Meta:
        db_table = 'annotations'


class Collage(models.Model):
    annotatable_type = models.CharField(max_length=255, blank=True, null=True)
    annotatable_id = models.IntegerField(blank=True, null=True)
    name = models.CharField(max_length=250)
    description = models.CharField(max_length=5120, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    word_count = models.IntegerField(blank=True, null=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    public = models.BooleanField(blank=True, null=True, default=True)
    readable_state = models.CharField(max_length=5242880, blank=True, null=True)
    words_shown = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField(default=0)
    annotator_version = models.IntegerField(default=2)
    featured = models.BooleanField(default=False)
    created_via_import = models.BooleanField(default=False)
    version = models.IntegerField(default=1)
    enable_feedback = models.BooleanField(default=True)
    enable_discussions = models.BooleanField(default=False)
    enable_responses = models.BooleanField(default=False)

    class Meta:
        db_table = 'collages'
        indexes = [
            models.Index(fields=['ancestry']),
            models.Index(fields=['annotatable_id']),
            models.Index(fields=['annotatable_type']),
            models.Index(fields=['created_at']),
            models.Index(fields=['name']),
            models.Index(fields=['public']),
            models.Index(fields=['updated_at']),
            models.Index(fields=['word_count'])
        ]


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


class DelayedJob(models.Model):
    priority = models.IntegerField(blank=True, null=True, default=0)
    attempts = models.IntegerField(blank=True, null=True, default=0)
    handler = models.TextField(blank=True, null=True)
    last_error = models.TextField(blank=True, null=True)
    run_at = models.DateTimeField(blank=True, null=True)
    locked_at = models.DateTimeField(blank=True, null=True)
    failed_at = models.DateTimeField(blank=True, null=True)
    locked_by = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    queue = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        db_table = 'delayed_jobs'
        indexes = [
            models.Index(fields=['priority', 'run_at']),
        ]


class FrozenItem(models.Model):
    content = models.TextField(blank=True, null=True)
    version = models.IntegerField()
    item_id = models.IntegerField()
    item_type = models.CharField(max_length=255)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'frozen_items'


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


class Metadata(models.Model):
    contributor = models.CharField(max_length=255, blank=True, null=True)
    coverage = models.CharField(max_length=255, blank=True, null=True)
    creator = models.CharField(max_length=255, blank=True, null=True)
    date = models.DateField(blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    format = models.CharField(max_length=255, blank=True, null=True)
    identifier = models.CharField(max_length=255, blank=True, null=True)
    language = models.CharField(max_length=255, blank=True, null=True, default='en')
    publisher = models.CharField(max_length=255, blank=True, null=True)
    relation = models.CharField(max_length=255, blank=True, null=True)
    rights = models.CharField(max_length=255, blank=True, null=True)
    source = models.CharField(max_length=255, blank=True, null=True)
    subject = models.CharField(max_length=255, blank=True, null=True)
    title = models.CharField(max_length=255, blank=True, null=True)
    dc_type = models.CharField(max_length=255, blank=True, null=True, default='Text')
    classifiable_type = models.CharField(max_length=255, blank=True, null=True)
    classifiable_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'metadata'
        indexes = [
            models.Index(fields=['classifiable_id']),
            models.Index(fields=['classifiable_type']),
        ]


class Page(models.Model):
    page_title = models.CharField(max_length=255)
    slug = models.CharField(max_length=255)
    content = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    footer_link = models.BooleanField(default=False)
    footer_link_text = models.CharField(max_length=255, blank=True, null=True)
    footer_sort = models.IntegerField(default=1000)
    is_user_guide = models.BooleanField(default=False)
    user_guide_sort = models.IntegerField(default=1000)
    user_guide_link_text = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        db_table = 'pages'


class PermissionAssignment(models.Model):
    user_collection_id = models.IntegerField(blank=True, null=True)
    user_id = models.IntegerField(blank=True, null=True)
    permission_id = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'permission_assignments'


class Permission(models.Model):
    key = models.CharField(max_length=255, blank=True, null=True)
    label = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    permission_type = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        db_table = 'permissions'


class PlaylistItem(models.Model):
    playlist_id = models.IntegerField(blank=True, null=True)
    position = models.IntegerField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    public_notes = models.BooleanField(default=True)
    actual_object_type = models.CharField(max_length=255, blank=True, null=True)
    actual_object_id = models.IntegerField(blank=True, null=True)

    class Meta:
        db_table = 'playlist_items'
        indexes = [
            models.Index(fields=['position'])
        ]


class Playlist(models.Model):
    name = models.CharField(max_length=1024, blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)
    updated_at = models.DateTimeField(blank=True, null=True)
    public = models.BooleanField(blank=True, null=True, default=True)
    ancestry = models.CharField(max_length=255, blank=True, null=True)
    position = models.IntegerField(blank=True, null=True)
    counter_start = models.IntegerField(default=1)
    location_id = models.IntegerField(blank=True, null=True)
    when_taught = models.CharField(max_length=255, blank=True, null=True)
    user_id = models.IntegerField(default=0)
    primary = models.BooleanField(default=False)
    featured = models.BooleanField(default=False)
    created_via_import = models.BooleanField(default=False)

    class Meta:
        db_table = 'playlists'
        indexes = [
            models.Index(fields=['ancestry']),
            models.Index(fields=['position']),
        ]


class PlaylistsUserCollection(models.Model):
    # NB: This table does not have a primary key in production,
    # which Django can't deal with, and cannot recreate when instantiating the table
    playlist_id = models.IntegerField(blank=True, null=True)
    user_collection_id = models.IntegerField(blank=True, null=True)

    class Meta:
        db_table = 'playlists_user_collections'


class Tagging(models.Model):
    tag_id = models.IntegerField(blank=True, null=True)
    taggable_id = models.IntegerField(blank=True, null=True)
    tagger_id = models.IntegerField(blank=True, null=True)
    tagger_type = models.CharField(max_length=255, blank=True, null=True)
    taggable_type = models.CharField(max_length=255, blank=True, null=True)
    context = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = 'taggings'
        unique_together = (('tag_id', 'taggable_id', 'taggable_type', 'context', 'tagger_id', 'tagger_type'),)
        indexes = [
            models.Index(fields=['context']),
            models.Index(fields=['tag_id']),
            models.Index(fields=['taggable_id', 'taggable_type', 'context']),
            models.Index(fields=['taggable_id', 'taggable_type', 'tagger_id', 'context']),
            models.Index(fields=['taggable_id']),
            models.Index(fields=['taggable_type']),
            models.Index(fields=['tagger_id', 'tagger_type']),
            models.Index(fields=['tagger_id']),
            models.Index(fields=['tagger_type'])
        ]


class Tag(models.Model):
    name = models.CharField(max_length=255, blank=True, null=True)
    taggings_count = models.IntegerField(blank=True, null=True, default=0)

    class Meta:
        db_table = 'tags'
        indexes = [
            models.Index(fields=['taggings_count'])
        ]
