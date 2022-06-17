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

class ContentNode(EditTrackedModel, TimestampedModel, BigPkModel, MaterializedPathTreeMixin, TrackedCloneable):
    title = models.CharField(max_length=10000, default="Untitled")
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)
    # legacy field: https://github.com/harvard-lil/h2o/issues/1044
    raw_headnote = models.TextField(blank=True, null=True)
    headnote_doc_class = models.CharField(max_length=40, blank=True, null=True)
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

    # legacy casebook nodes only
    public = models.BooleanField(default=False)
    draft_mode_of_published_casebook = models.BooleanField(blank=True, null=True,
                                                           help_text='Unknown (None) or True; never False')

    # sections and resources only
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete Casebook contents in the Casebook.delete method.
    old_casebook = models.ForeignKey(
        'ContentNode',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name='old_casebook_contents'
    )

    casebook = models.ForeignKey(
        'Casebook',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name='contents'
    )

    # This field, together with resource_id, defines a relationship with Link, Textblock, or LegalDocument.
    # May also be blank, 'Section', or 'Temp'.
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

    _resource_prefetched = False
    _resource = None

    @property
    def resource(self):
        """
        Resource nodes are each related to one LegalDocument, TextBlock, or Link object,
        which has historically been referred to as the node's "resource."

        (Resource nodes might more accurately be called "ResourceWrapper"
        objects, or similar.)

        This method retrieves the node's related resource, in the manner one
        would expect to be able to do if this relationship were achieved via
        foreign keys (not possible on the Django side, without altering the
        database so as to support generic foreign keys or polymorphic models).
        """
        if hasattr(self,'_resource_prefetched') and not self._resource_prefetched:
            if not self.resource_id:
                return None
            if self.resource_type in ['TextBlock', 'Link', 'LegalDocument']:
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
        first_ordinals = f"ordinals__0_{len(self.ordinals)}"
        filter_map = {
            "casebook_id": self.casebook_id,
            first_ordinals: self.ordinals
        }
        res = ContentNode.objects.filter(**filter_map).exclude(id=self.id)
        return res

    def rendered_header(self):
        if self.is_resource and self.resource_type == 'LegalDocument':
            return render_to_string(self.resource.header_template,
                                {'legal_doc': self.resource, 'resource': self})
        return ''

    def export_postprocess(self, body, export_options=None):
        if self.resource_type == 'LegalDocument':
            api_model = self.resource.source.api_model()
            if hasattr(api_model, 'postprocess_content'):
                return api_model.postprocess_content(body, self.id, export_options=export_options)
        return body

    def headerless_export_content(self, request):
        if self.resource_type == 'TextBlock':
            return rich_text_export(self.resource.content, request=request, id_prefix=str(self.id))
        return prefix_ids_hrefs(self.resource.content, str(self.id))

    def export_content(self, request):
        if self.resource_type == 'LegalDocument':
            contents = prefix_ids_hrefs(self.resource.content, str(self.id))
            header = self.rendered_header()
            return f'{header}{contents}'
        elif self.resource_type == 'TextBlock':
            return rich_text_export(self.resource.content, request=request, id_prefix=str(self.id))
        return self.resource.content

    @property
    def is_temporary(self):
        return self.resource_type == 'Temp'

    @property
    def can_publish(self):
        return self.casebook.can_publish

    @property
    def has_body(self):
        return bool(self.resource_type and self.resource_type != 'Temp' and self.resource_type != 'Section')

    @property
    def provides_header(self):
        return not (self.resource_type is None or self.resource_type in {'Section', 'TextBlock', 'Link'})

    @property
    def body(self):
        return (self._resource or self.resource) if self.has_body else None

    @property
    def body_template(self):
        if not self.has_body:
            return 'includes/bodies/empty.html'
        return {'Link': 'includes/bodies/link.html',
                'TextBlock': 'includes/bodies/text_block.html',
                'LegalDocument':'includes/bodies/legal_doc.html'}[self.resource_type]

    def identify_headnote_type(self):
        if not self.headnote:
            return 'Text'
        pq = PyQuery(self.headnote)
        if pq('embed') or pq('img') or pq('iframe'):
            return 'Multimedia'
        return 'Text'

    @property
    def doc_class(self):
        if not self.resource_type or self.resource_type == 'Section':
            return 'Section'
        if self.resource_type == 'TextBlock':
            if self.resource.doc_class == 'Text' and self.headnote_doc_class == 'Text':
                return 'Text'
            return (self.resource.doc_class != 'Text' and self.resource.doc_class) or \
                   (self.headnote_doc_class != 'Text' and self.headnote_doc_class) or \
                   'Text'
        if self.resource_type == 'LegalDocument':
            return self.resource.doc_class
        return self.resource_type

    def get_export_class(self):
        """
        This is an experiment, attempting to infer book structure from a node's type and location in the content tree,
        for easier handling of page breaks, page headers and footers, and the application of word styles.

        Conventions, abstracted from the typeset Torts! PDF produced by Jordi:
        - "chapters" (e.g. ordinal 5) should start on an odd page... and chapters may be sections or textblocks
        - top-level chapter "sections" (e.g. ordinal 5.2) should start on a new page, even or odd
        - more deeply nested sub-"sections" (e.g. ordinal 4.1.2) should be continuous
        - resources inside sections (of any kind) (4.1.1, 4.1.2.1) should be continuous

        But, those conventions don't apply across the board.
        - some casebooks have cases at the top level
        - sometimes textblocks in sections seem to be introductions or conclusions to their wrapper; sometimes stand-alone resources

        More thought is needed here.
        Should probably be configurable?
        - easy enough to have node-by-node setting, but could clutter the UI.
        - and/or, we ought to be able to abstract out can capture a few common patterns that authors can opt to apply to their export or not,
          e.g., an arg to this method.
        Or, we might consider enhancing the data model to distinguish between frontmatter, endmatter, book parts, chapters, and chapter sections, etc.
        """
        depth = len(self.ordinals)
        if not depth:
            raise NotImplementedError
        if depth == 1:
            if self.doc_class in ['Section', 'Text', 'Multimedia']:
                return 'Chapter'
            return 'Leading Resource'
        elif self.doc_class == 'Section':
            if depth == 2:
                return 'Section'
            return 'Subsection'
        return 'Resource'


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
        self.headnote_doc_class = self.identify_headnote_type()
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        """
            Override delete, to ensure the tree is re-ordered afterwards,
            and to clean up now-unused TextBlock and Link resources.

            Given:
            >>> full_casebook_parts_factory, assert_num_queries = [getfixture(i) for i in ['full_casebook_parts_factory','assert_num_queries']]

            # Sections
            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = full_casebook_parts_factory()

            Delete a section in a section (and children, including one case, one text block, and one link/default), no reordering required:
            >>> with assert_num_queries(delete=5, select=15, update=1, insert=8):
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
            >>> with assert_num_queries(delete=5, select=14, update=1, insert=8):
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
            >>> with assert_num_queries(delete=2, select=5, update=1, insert=3):
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
            >>> with assert_num_queries(delete=2, select=7, update=1, insert=2):
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
            >>> with assert_num_queries(delete=2, select=7, update=1, insert=2):
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
            parent = ContentNode.objects.get(casebook=self.casebook, ordinals=ordinals_of_parent)
        else:
            parent = self.casebook

        # Delete this nodes's children, and any related links and textblocks,
        # without recursively calling this custom delete method
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

    def _delete_related_links_and_text_blocks(self):
        """
            A private utility for efficiently deleting associated Link and TextBlock objects.
        """
        if self.type != 'section':
            raise NotImplementedError

        to_delete = {Link: [], TextBlock: []}
        for resource in self.contents.prefetch_resources():
            if resource.resource_id and resource.resource_type in ('Link', 'TextBlock'):
                to_delete[type(resource._resource)].append(resource.resource_id)
        for cls, ids in to_delete.items():
            cls.objects.filter(id__in=ids).delete()

    def get_slug(self):
        return slugify(self.title)

    def viewable_by(self, user):
        return self.casebook.viewable_by(user)

    def directly_editable_by(self, user):
        """
        Allow a user to make real-time changes (e.g., via edit view),
        rather than requiring them to make changes via the draft mechanism.
        (See allows_draft_creation_by for more discussion of editing and drafts.)
        """
        return self.casebook.is_private and self.casebook.editable_by(user)

    def __str__(self):
        return f"{self.title} ({self.id})"

    @property
    def is_legacy_casebook_node(self):
        return not self.ordinals

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
        first_ordinals = f"ordinals__0_{len(self.ordinals)}"
        filter_map = {
            "casebook_id": self.casebook_id,
            first_ordinals: self.ordinals
        }
        return ContentNode.objects.filter(**filter_map).exclude(id=self.id)

    @property
    def annotatable(self):
        """
        Only particular kinds of resources can be annotated.
        """
        return self.type == 'resource' and self.resource_type in ['TextBlock', 'LegalDocument']

    def get_annotate_url(self):
        """
        If a resource can be annotated, returns the URL for the page an author
        uses to make annotations. Otherwise, returns a ValueError.
        """
        if self.annotatable:
            return reverse('annotate_resource', args=[self.casebook, self])
        raise ValueError('Only Resources (LegalDocument and TextBlock) can be annotated.')

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
          LegalDocument/Text:
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
        if not self.resource_type or self.resource_type == 'Section':
            return 'section'
        elif self.resource_type == 'Temp':
            return 'temp'
        else:
            return 'resource'

    def export(self, include_annotations, file_type='docx', export_options=None, is_child=False, docx_footnotes=None):
        """
            Export this node and children as docx, or as html for conversion by pandoc.

            Given:
            >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

            Export uses 8 queries: selecting descendant nodes, and prefetching ContentAnnotation, Case, TextBlock, and Link, and provenance info
            >>> with assert_num_queries(select=12, delete=1, insert=1):
            ...     file_data = full_casebook.export(include_annotations=True)
        """

        docx_sections = export_options['docx_sections'] if export_options and 'docx_sections' in export_options else settings.FORCE_DOCX_SECTIONS

        # prefetch all child nodes and related data
        if LiveSettings.load().prevent_exports:
            logger.info(f"Exporting Casebook {self.id}: attempt rejected (too many previous failures)")
            return None

        docx_footnotes = docx_footnotes if docx_footnotes is not None else settings.FORCE_DOCX_FOOTNOTES

        children = list(self.contents.prefetch_resources().prefetch_related('annotations')) if type(
            self) is not Resource else None

        current_collaborators = set(self.casebook.primary_authors)
        cloned_from = {cn.casebook for cn in self.ancestor_nodes.prefetch_related('casebook')
                                                   .prefetch_related('casebook__contentcollaborator_set')
                                                   .prefetch_related('casebook__contentcollaborator_set__user')
                         if set(cn.casebook.primary_authors) ^ current_collaborators}

        # render html
        if not self.resource_type or self.resource_type == 'Section':
            template_name = 'export/section.html'
        elif self.resource_type == 'Temp':
            template_name = 'export/tbd.html'
        else:
            template_name = 'export/node.html'

        if not docx_sections:
            template_name = template_name.replace('export/', 'export/old_pr1491/')

        html = render_to_string(template_name, {
            'is_export': True,
            'is_child': is_child,
            'node': self,
            'children': children,
            'include_annotations': include_annotations,
            'export_options': export_options,
            'export_date': datetime.now().strftime("%Y-%m-%d"),
            'cloned_from': cloned_from,
        })

        if file_type == 'html':
            return html
        if not LiveSettings.export_is_rate_limited():
            return export_via_aws_lambda(self, html, file_type, docx_footnotes=docx_footnotes, docx_sections=docx_sections)
        logger.info(f"Exporting {self.type} {self.id} prevented due to rate limits")
        return None

    def headnote_for_export(self, export_options=None):
        r"""
            Return headnote HTML prepared for pandoc export.

            >>> assert Resource(headnote='<p>An image <img src=""></p>').headnote_for_export() == '<p>An image <img src=""></p>'
        """
        if not self.headnote:
            return ''
        html = rich_text_export(self.headnote, request=export_options and export_options.get('request'), id_prefix=str(self.id))
        return mark_safe(html)

    @staticmethod
    def update_tree_for_export(tree, export_options=None):
        """
            Prepare an lxml tree (annotated or un-annotated) for export.
        """
        tree = PyQuery(tree)

        # Case Header styling
        for pq in tree('section.head-matter p, center, p[style="text-align:center"], p[align="center"]').items():
            pq.wrap("<div data-custom-style='Case Header'></div>")
        for el in tree('section.head-matter h4, center h2, h2[style="text-align:center"], h2[align="center"]'):
            el.tag = 'div'
            el.attrib['data-custom-style'] = 'Case Header'

        return tree

    def content_for_export(self, export_options=None):
        r"""
            Return content as html for export to Pandoc, without annotations.

            >>> resource, *_ = [getfixture(f) for f in ['resource']]
            >>> resource.resource.content = '<center>Title</center><h2 align="center">Subtitle</h2><p>An image <img src=""></p>'
            >>> output = '<header class="case-header">\n</header>\n<div><center>Title</center><h2 align="center">Subtitle</h2><p>An image <img src=""></p></div>'
            >>> assert resource.content_for_export() == output
        """
        html = self.export_content(export_options and export_options.get('request'))
        return mark_safe(html)

    def annotated_content_for_export(self, export_options=None):
        r"""
            Return content as html for export to Pandoc, with annotations.

            Given:
            >>> annotations_factory, *_ = [getfixture(f) for f in ['annotations_factory']]
            >>> def assert_match(source_html, expected_html):
            ...     annotated_html = annotations_factory('LegalDocument', source_html)[1].annotated_content_for_export()
            ...     assert elements_equal(
            ...         parse_html_fragment(annotated_html),
            ...         parse_html_fragment(expected_html),
            ...         ignore_trailing_whitespace=True
            ...     ), f"Expected:\n{expected_html}\nGot:\n{annotated_html}"

            Basic format of all annotations:
            >>> input = '''<p>
            ...     [note my note]Has a note[/note]
            ...     [highlight]is highlighted[/highlight]
            ...     [elide]is elided[/elide]
            ...     [replace new content]is replaced[/replace]
            ...     [correction replaced content]is replaced[/correction]
            ...     [link http://example.com]is linked[/link]
            ... </p>'''
            >>> content_node = annotations_factory('LegalDocument', input)[1]
            >>> output_html = content_node.annotated_content_for_export()
            >>> expected = f'''<header class="case-header">
            ...     </header><p>
            ...     <span class="annotate">Has a note</span><span data-custom-style="Footnote Reference">*</span>
            ...     <span class="annotate highlighted" data-custom-style="Highlighted Text">is highlighted</span>
            ...     <span data-custom-style="Elision">[ … ]</span>
            ...     <span data-custom-style="Replacement Text">new content</span>
            ...     replaced content
            ...     <a class="annotate" href="http://example.com">is linked</a><span data-custom-style="Footnote Reference">**</span>
            ... </p>'''
            >>> assert elements_equal(parse_html_fragment(output_html), parse_html_fragment(expected),ignore_trailing_whitespace=True), f"Expected:\n{expected}\nGot:\n{output_html}"

            Annotation spanning paragraphs:
            >>> input = '''
            ... <p>Some [highlight] text</p>
            ... <p>Some <em>text</em></p>
            ... <p>Some [/highlight] text</p>
            ... '''
            >>> expected = '''<header class="case-header">
            ...     </header>
            ... <div><p>Some <span class="annotate highlighted" data-custom-style="Highlighted Text"> text</span></p>
            ... <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Some </span><em><span class="annotate highlighted" data-custom-style="Highlighted Text">text</span></em></p>
            ... <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Some </span> text</p></div>
            ... '''
            >>> assert_match(input, expected)

            Deletion spanning paragraphs:
            >>> input = '''<p>Some [replace new content] text</p>
            ... <p>Some <em>text</em> <br></p>
            ... <p>Some [/replace] text</p>'''
            >>> expected = '''<header class="case-header">
            ...     </header>
            ... <div><p>Some <span data-custom-style="Replacement Text">new content</span></p><p> text</p></div>
            ... '''
            >>> assert_match(input, expected)

            Void elements:
            >>> input = '''<p> [highlight] <br> [/highlight] </p>'''
            >>> expected = '''<header class="case-header">
            ...     </header><p> <span class="annotate highlighted" data-custom-style="Highlighted Text"> </span><br><span class="annotate highlighted" data-custom-style="Highlighted Text"> </span> </p>'''
            >>> assert_match(input, expected)

            Annotations with ambiguous placement:
            >>> input = '<p>First</p><p>[highlight]Second[/highlight]</p><p>Third</p>'
            >>> expected = '<header class="case-header">\
            ...     </header><div><p>First</p><p><span class="annotate highlighted" data-custom-style="Highlighted Text">Second</span></p><p>Third</p></div>'
            >>> assert_match(input, expected)
            >>> input = '<p>First</p><p>[elide]Second[/elide]</p><p>Third</p>'
            >>> expected = '<header class="case-header">\
            ...     </header><div><p>First</p><p><span data-custom-style="Elision">[ … ]</span></p><p>Third</p></div>'
            >>> assert_match(input, expected)
            >>> input = '<p>[highlight]First[/highlight]</p><p>[highlight]Sec[/highlight][highlight]ond[/highlight]</p><p>[highlight]Third[/highlight]</p>'
            >>> expected = '<header class="case-header">\
            ...     </header><div><p><span class="annotate highlighted" data-custom-style="Highlighted Text">First</span></p>' \
            ...     '<p><span class="annotate highlighted" data-custom-style="Highlighted Text">Sec</span><span class="annotate highlighted" data-custom-style="Highlighted Text">ond</span></p>' \
            ...     '<p><span class="annotate highlighted" data-custom-style="Highlighted Text">Third</span></p></div>'
            >>> assert_match(input, expected)

            Overlapping annotations:
            (Not sure if these can happen in practice, but they do work for export, at least in simple cases.)
            >>> input = '<p>[highlight]One [note my note]two[/highlight] three[/note]</p>'
            >>> content_node = annotations_factory('LegalDocument', input)[1]
            >>> output_html = content_node.annotated_content_for_export()

            >>> expected = f'<header class="case-header">\n</header><p><span class="annotate highlighted" data-custom-style="Highlighted Text">One <span class="annotate">two</span></span>' \
            ...     f'<span class="annotate"> three</span><span data-custom-style="Footnote Reference">*</span></p>'
            >>> assert elements_equal(parse_html_fragment(output_html), parse_html_fragment(expected),ignore_trailing_whitespace=True), f"Expected:\n{expected}\nGot:\n{output_html}"
            >>> input = '<p>[highlight]One [elide]two[/highlight] three[/elide]</p>'
            >>> expected = '<header class="case-header">\n</header><p><span class="annotate highlighted" data-custom-style="Highlighted Text">One <span data-custom-style="Elision">[ … ]</span></span></p>'
            >>> assert_match(input, expected)

            Annotations with invalid offsets are clamped:
            >>> input = '<p>[highlight]F[/highlight]oo</p>'
            >>> expected = '<header class="case-header">\n</header>\n<p><span class="annotate highlighted" data-custom-style="Highlighted Text">Foo</span></p>'
            >>> resource = annotations_factory('LegalDocument', input)[1]
            >>> _ = resource.annotations.update(global_end_offset=1000)  # move end offset past end of text
            >>> assert resource.annotated_content_for_export() == expected
        """
        # Start with a sorted list of the start and end insertion points for each annotation.
        # Each entry in the list is shaped like (annotation_offset, is_start_tag, annotation).
        # Clamp offsets to the max valid value, as we may have legacy invalid values in the database that are too large.
        doc = self.headerless_export_content(export_options and export_options.get('request'))
        if not doc:
            return doc
        pq = PyQuery(doc)
        source_tree = pq[0]
        max_valid_offset = len("".join([x for x in pq[0].itertext()]))
        annotations = []
        for annotation in self.annotations.all():
            # equivalent test to self.annotation.valid(),but using all() lets us use prefetched querysets
            if annotation.global_start_offset < 0 or annotation.global_end_offset < 0:
                continue
            annotations.append((min(annotation.global_start_offset, max_valid_offset), True, annotation))
            annotations.append((min(annotation.global_end_offset, max_valid_offset), False, annotation))
        # sort by first two fields, so we're ordered by offset, then we get end tags and then start tags for a given offset
        annotations.sort(key=lambda a: (a[0],not a[1]))
        # This SAX ContentHandler does the heavy lifting of stepping through each HTML tag and text string in the
        # source HTML and building a list of destination tags and text, inserting annotation tags or deleting text
        # as appropriate:

        postfix_id = self.id
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
                                'data-custom-style': 'Elision' if kind == 'elide' else 'Replacement Text'}))
                            self.addText(annotation.content or '' if kind == 'replace' else '[ … ]')
                            self.out_ops.append((self.out_handler.endElement, 'span'))
                            self.elide += 1
                        else:
                            self.elide = max(self.elide - 1, 0)  # decrement, but no lower than zero
                    elif kind == 'correction':
                        if is_start_tag:
                            self.elide += 1
                            self.addText(annotation.content or '')
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
                                            {'class': 'annotate highlighted', 'data-custom-style': 'Highlighted Text'})
                                close_tag = (self.out_handler.endElement, 'span')
                            else:
                                raise ValueError(f"Unknown annotation kind '{kind}'")

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
                                footnote_ref = "Footnote Reference" + (f"-{postfix_id}" if export_options and export_options.get('docx_footnotes', False) else "")
                                self.out_ops.append(
                                    (self.out_handler.startElement, 'span', {'data-custom-style': footnote_ref}))
                                self.addText('*' * self.footnote_index)
                                self.out_ops.append((self.out_handler.endElement, 'span'))

                # emit any text that comes after the final annotation in this text string:
                if data and not self.elide:
                    self.addText(data)

            def startElementNS(self, name, qname, attributes):
                """ Handle opening elements from the source HTML. """
                if self.omitTag(name[1]):
                    return
                if attributes and (None, 'data-extra-export-offset') in attributes:
                    extra_offset = int(attributes.getValueByQName('data-extra-export-offset'))
                    self.offset -= extra_offset
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
        return mark_safe(self.rendered_header() + self.export_postprocess(html.tostring(dest_tree).decode('utf-8'), export_options=export_options))

    def footnote_annotations(self, export_options=None):
        postfix_id=self.id
        style = "Footnote Text" + (f"-{postfix_id}" if export_options and export_options.get('docx_footnotes', False) else "")
        return mark_safe("".join(
            format_html('<div data-custom-style="{}"><span data-custom-style="Footnote Ref">{}</span> {} </div>',style, "*" * (i + 1), annotation.content)
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

    @property
    def primary_authors(self):
        return self.casebook.primary_authors

    @property
    def originating_authors(self):
        if self.type == 'Section':
            originating_nodes = set([cloned_node for child_content in self.contents.all() for cloned_node in child_content.provenance])
        else:
            if not self.provenance:
                return set()
            originating_nodes = set(self.provenance)
        users = [collaborator.user for cn in
                    ContentNode.objects.filter(id__in=originating_nodes)
                        .select_related('casebook')
                        .prefetch_related('casebook__contentcollaborator_set__user')
                        .all()
                    for collaborator in cn.casebook.contentcollaborator_set.order_by('id').all() if collaborator.has_attribution and collaborator.user.attribution != 'Anonymous']
        return set(users)

    @property
    def has_non_current_authors(self):
        return len(self.non_current_authors) > 0

    @property
    def non_current_authors(self):
        ogs = self.originating_authors
        cgs = self.primary_authors
        return ogs.difference(cgs)

    @property
    def is_public(self):
        return self.casebook.is_public

    @property
    def is_private(self):
        return not self.is_public

    @property
    def permits_cloning(self):
        """
        Allow a user to clone this node.

        This method should be implemented by all children.
        """
        return self.casebook.permits_cloning

    def editable_by(self, user):
        return self.casebook.editable_by(user)

    @property
    def has_draft(self):
        return self.casebook.has_draft

    @property
    def is_draft(self):
        return self.casebook.is_draft

    def allows_draft_creation_by(self, user):
        return self.casebook.allows_draft_creation_by(user)

    def is_annotated(self):
        """
        While only Resources can be annotated, it is useful to know if a
        Section contains Resources that have been annotated,
        and it is useful to have a single interface for finding
        Sections and Resources associated with annotations.
        """
        if self.resource_id:
            return self.annotations.count() > 0
        else:
            return any(node.annotations for node in self.contents.prefetch_related('annotations'))

    # URLs

    def get_absolute_url(self):
        """
        Since Sections, and Resources can all be accessed
        from URLs that include slugs AND from urls that omit slugs,
        instruct Django how to calculate the canonical URL for each object.
        https://docs.djangoproject.com/en/2.2/ref/models/instances/#get-absolute-url
        """
        if self.resource_id or self.resource_type == 'Temp':
            return reverse('resource', args=[self.casebook, self])
        else:
            return reverse('section', args=[self.casebook, self])

    def get_edit_url(self):
        """
        A convenience method, for retrieving the edit URL of a
        Section, or Resource without having to specify the view name,
        which is useful in shared templates.
        """
        if self.resource_id or self.resource_type == 'Temp':
            return reverse('edit_resource', args=[self.casebook, self])
        else:
            return reverse('edit_section', args=[self.casebook, self])

    def get_draft_url(self):
        """
        If this node is or belongs to a Casebook that has a draft, return
        the URL of the draft's "edit" page. Otherwise, return a ValueError.

        This method should be implemented by all children.
        """
        return self.casebook.get_draft_url

    def get_edit_or_absolute_url(self, editing=False):
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
        return self.casebook.testing_editor

    def clone_to(self, target_casebook):
        """
            Clone a section or resource from its current casebook to a new casebook.

            This is currently called only manually, for extraordinary customer service situations, but would ideally
            be exposed through the frontend.

            Given:
            >>> reset_sequences, full_casebook_parts_factory = [getfixture(i) for i in ['reset_sequences', 'full_casebook_parts_factory']]
            >>> from_casebook = full_casebook_parts_factory()[0]
            >>> to_casebook = full_casebook_parts_factory()[0]
            >>> section = from_casebook.sections[1]
            >>> og_section_outline = dump_content_tree(section)
            >>> resource = from_casebook.resources[0]

            Can append a section or a resource to the end of to_casebook:
            >>> t = dump_casebook_outline(to_casebook)[-7:]
            >>> section.clone_to(to_casebook)
            >>> u = dump_casebook_outline(to_casebook)[-7:]
            >>> resource.clone_to(to_casebook)
            >>> v = dump_casebook_outline(to_casebook)[-7:]
            >>> assert dump_casebook_outline(to_casebook)[-7:] == [
            ...   ' Section<19>: Some Section 4',
            ...   '  ContentNode<20> -> TextBlock<5>: Some TextBlock Name 1',
            ...   '  ContentNode<21> -> LegalDocument<2>: Legal Doc 1',
            ...   '   ContentAnnotation<9>: note 0-10',
            ...   '   ContentAnnotation<10>: replace 0-10',
            ...   '  ContentNode<22> -> Link<5>: Some Link Name 1',
            ...   ' ContentNode<23> -> TextBlock<6>: Some TextBlock Name 0'
            ... ]

            Ordinals are properly updated:
            >>> assert [node.ordinals for node in list(to_casebook.contents.all())[-5:]] == [[3], [3, 1], [3, 2], [3, 3], [4]]
        """
        contents = list(self.contents) if type(self) is Section or type(self) is Casebook else []
        target_casebook.clone_nodes(([self] if type(self) is not Casebook else []) + contents, append=True)

    @property
    def in_edit_state(self):
        return self.casebook.in_edit_state

    def tabs_for_user(self, user, current_tab=None):
        read_tab = 'Preview' if self.in_edit_state else 'Read'
        if current_tab is None:
            current_tab = read_tab
        tabs = [('Casebook', reverse('casebook', args=[self.casebook]), True),
                ('Edit', reverse('edit_resource', args=[self.casebook, self]), self.in_edit_state and self.editable_by(user)),
                ('Annotate', reverse('annotate_resource', args=[self.casebook, self]), self.in_edit_state and self.editable_by(user) and self.annotatable),
                (read_tab, reverse('section', args=[self.casebook, self]), True),
                ('Credits', reverse('show_resource_credits', args=[self.casebook, self]), True)]
        return [(n, l, n == current_tab) for n,l,c in tabs if c]

    @property
    def descendant_nodes(self):
        ids = [cn.id for cn in self.contents.all()] + [self.id]
        return ContentNode.objects.filter(provenance__overlap=ids).filter(casebook__state='Public')

    @property
    def ancestor_nodes(self):
        ids = [p for cn in self.contents.all() for p in cn.provenance] + [p for p in self.provenance]
        return ContentNode.objects.filter(id__in=ids).filter(casebook__state='Public')

    @property
    def related_docs(self):
        docs = None
        if self.resource_type == 'LegalDocument':
            docs = [self]
        else:
            docs = [x for x in self.contents.filter(resource_type='LegalDocument').prefetch_resources()]

        src_refs = {(doc.resource.source_id, doc.resource.source_ref) for doc in docs}
        legal_doc_sources = {src for src, _ in src_refs}
        legal_doc_refs = {ref for _, ref in src_refs}

        lds = {ld.id for ld in LegalDocument.objects.filter(source_id__in=legal_doc_sources, source_ref__in=legal_doc_refs).all() if (ld.source_id, ld.source_ref) in src_refs}
        return ContentNode.objects.filter(resource_type='LegalDocument',resource_id__in=lds).filter(casebook__state='Public').prefetch_related('casebook')

#
# Start ContentNode Proxies
#

class Section(ContentNode):
    class Meta:
        proxy = True


class Resource(ContentNode):
    class Meta:
        proxy = True
