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

class CasebookEditLog(BigPkModel):
    casebook = models.ForeignKey('Casebook',
        on_delete=models.DO_NOTHING,
        blank=False,
        null=False,
        related_name='edit_log'
    )

    entry_date = models.DateTimeField(auto_now_add=True, blank=False, null=False)
    class ChangeType(Enum):
        REMOVED = "Removed"
        ADDED = "Added"
        EDITED = "Edited"
        ANNOTATED = "Annotated"
        ORIGINAL_PUBLISH = "First"

    change = models.CharField(
      max_length=10,
      choices=[(tag.value, tag.name) for tag in ChangeType]
    )
    # This is a pointer to the content we direct people to on the history page.
    # It may result in a redirect if there's been more than one edit. Updated on GC.
    content = models.ForeignKey('ContentNode',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='edit_log'
    )

    @property
    def description_line(self):
        line = ""
        if self.change == CasebookEditLog.ChangeType.REMOVED.value:
            self.content.content_tree__load()
            parent = self.content.content_tree__parent or self.content.casebook
            line = f"Removed {self.content.title} from <a href='{self.content.get_absolute_url()}'>{parent.title}</a>"
        elif self.change == CasebookEditLog.ChangeType.ADDED.value:
            line = f"Added <a href='{self.content.get_absolute_url()}'>{self.content.title}</a>"
        elif self.change == CasebookEditLog.ChangeType.EDITED.value:
            line = f"Edited <a href='{self.content.get_absolute_url()}'>{self.content.title}</a>"
        elif self.change == CasebookEditLog.ChangeType.ANNOTATED.value:
            line = f"Annotations changed on <a href='{self.content.get_absolute_url()}'>{self.content.title}</a>"
        elif self.change ==  CasebookEditLog.ChangeType.ORIGINAL_PUBLISH.value:
            line = "Casebook first published."
        return mark_safe(line)


class Casebook(EditTrackedModel, TimestampedModel, BigPkModel, TrackedCloneable):
    old_casebook = models.ForeignKey('ContentNode', on_delete=models.DO_NOTHING,blank=True,null=True,related_name='replacement_casebook')
    title = models.CharField(max_length=10000, default="Untitled")
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)

    collaborators = models.ManyToManyField('User',
                                           through='ContentCollaborator',
                                           related_name='casebooks'
                                           )
    @property
    def contentcollaborator_set(self):
        return self.contentcollaborator_set

    @property
    def attributed_authors(self):
        primary_set = set(self.primary_authors)
        return self.primary_authors + [x for x in self.originating_authors if x not in primary_set]

    class LifeCycle(Enum):
        PRIVATELY_EDITING = 'Fresh' # There is no public version of this casebook
        NEWLY_CLONED = 'Clone' # There is no public version of this casebook
        DRAFT = 'Draft' # This version is private, but a public version exists
        PUBLISHED = 'Public' # This version is public
        ARCHIVED = 'Archived' # This is retired, and is no longer public
        REVISING = 'Revising' # A public and private (with edits) version of this casebook exist. This is the public one
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
    export_fails = models.IntegerField(default=0)

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
        return bool(self.contentcollaborator_set.filter(user_id=user.id).first())

    def directly_editable_by(self, user):
        """
        Allow a user to make real-time changes (e.g., via edit view),
        rather than requiring them to make changes via the draft mechanism.
        (See allows_draft_creation_by for more discussion of editing and drafts.)
        """
        return self.is_private and self.editable_by(user)

    def __str__(self):
        return f"{self.title} ({self.id})"

    @property
    def casebook(self):
        return self

    def headnote_for_export(self, export_options=None):
        r"""
            Return headnote HTML prepared for pandoc export.

            >>> assert Resource(headnote='<p>An image <img src=""></p>').headnote_for_export() == '<p>An image <img src=""></p>'
        """
        if not self.headnote:
            return ''
        html = rich_text_export(self.headnote, request=export_options and export_options.get('request', None), id_prefix=str(self.id))
        return mark_safe(html)


    @property
    def is_resource(self):
        # This method is called by ContentNode.content_tree__move_to, if the target parent is a Casebook and not a ContentNode.
        return False

    @property
    def is_public(self):
        public_states = {x.value for x in [Casebook.LifeCycle.PUBLISHED, Casebook.LifeCycle.REVISING]}
        return self.state in public_states

    @property
    def public_version(self):
        if self.state == Casebook.LifeCycle.PUBLISHED.value:
            return self
        elif self.state == Casebook.LifeCycle.REVISING.value:
            return self
        elif self.state == Casebook.LifeCycle.DRAFT.value:
            prior_id = self.provenance and self.provenance[-1]
            return Casebook.objects.filter(id=prior_id).first()
        elif self.state == Casebook.LifeCycle.ARCHIVED.value:
            return None
        elif self.state == Casebook.LifeCycle.NEWLY_CLONED.value:
            return None
        elif self.state == Casebook.LifeCycle.PRIVATELY_EDITING.value:
            return None
        elif self.state == Casebook.LifeCycle.PREVIOUS_SAVE.value:
            pub_id = self.provenance and self.provenance[-1]
            return Casebook.objects.filter(id=pub_id).first()

    @property
    def is_private(self):
        return not self.is_public

    def is_annotated(self):
        return any(node.annotations for node in self.contents.prefetch_related('annotations'))

    def get_edit_or_absolute_url(self, editing=False):
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
            >>> assert CasebookEditLog.objects.exists()
            >>> with assert_num_queries(delete=14, select=20, insert=36):
            ...     deleted = casebook.delete()
            >>> assert not Casebook.objects.exists()
            >>> assert not ContentNode.objects.exists()
            >>> assert not ContentAnnotation.objects.exists()
            >>> assert not CasebookEditLog.objects.exists()
            >>> assert casebook.contentcollaborator_set.count() == 0
        """
        if self.draft:
            self.draft.delete()
        self._delete_related_links_and_text_blocks()
        self.contents.all().delete()
        self.contentcollaborator_set.all().delete()
        self.edit_log.all().delete()
        return super().delete(*args, **kwargs)

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
    def sections(self):
        return Section.objects.filter(casebook=self).filter(resource_type__isnull=True)

    @property
    def resources(self):
        return ContentNode.objects.filter(casebook=self,resource_id__isnull=False)

    @property
    def children(self):
        return ContentNode.objects.filter(casebook=self, ordinals__len=1)

    @property
    def sub_sections(self):
        return self.children

    @property
    def descendant_nodes(self):
        ids = [cn.id for cn in self.contents.all()]
        return ContentNode.objects.filter(provenance__overlap=ids).filter(casebook__state='Public')

    @property
    def ancestor_nodes(self):
        ids = [p for cn in self.contents.all() for p in cn.provenance]
        return ContentNode.objects.filter(id__in=ids).filter(casebook__state='Public')

    @property
    def related_docs(self):
        docs = [x for x in self.contents.filter(resource_type='LegalDocument').prefetch_resources()]
        src_refs = {(doc.resource.source_id, doc.resource.source_ref) for doc in docs}
        legal_doc_sources = {src for src, _ in src_refs}
        legal_doc_refs = {ref for _, ref in src_refs}

        lds = {ld.id for ld in LegalDocument.objects.filter(source_id__in=legal_doc_sources, source_ref__in=legal_doc_refs).all() if (ld.source_id, ld.source_ref) in src_refs}
        return ContentNode.objects.filter(resource_type='LegalDocument',resource_id__in=lds).filter(casebook__state='Public').prefetch_related('casebook')


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
        bulk_create_with_history(cloned_content_nodes, ContentNode, batch_size=500, default_change_reason=f"Restore from {self.id}")
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
        collabs = self.contentcollaborator_set.filter(user=user).first()
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
        if not self.is_public:
            return False
        if not self.editable_by(user):
            return False
        if not self.can_transition_to(Casebook.LifeCycle.REVISING):
            return False
        return not self.has_draft

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
        self.transition_to(Casebook.LifeCycle.REVISING)
        self.save()
        return self.clone(draft_mode=True)

    @transaction.atomic
    def merge_draft(self):
        """
            Merge draft casebook back into parent, and delete draft.

            Given:
            >>> reset_sequences, full_casebook, assert_num_queries, legal_document_factory = [getfixture(i) for i in ['reset_sequences', 'full_casebook', 'assert_num_queries', 'legal_document_factory']]
            >>> elena, john =  [User(attribution=name, email_address=f"{name}@scotus.gov") for name in ['Elena', 'John']]
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
            >>> Section(casebook=draft, ordinals=[3], title="New Section").save()
            >>> ld = legal_document_factory()
            >>> Resource(title='New TextBlock',
            ...          casebook=draft,
            ...          ordinals=[3,1],
            ...          resource_id=ld.id,
            ...          resource_type="LegalDocument").save()
            >>> with assert_num_queries(select=10, update=3, insert=4):
            ...     new_casebook = draft.merge_draft()
            >>> assert new_casebook == full_casebook
            >>> expected = [
            ...       'Casebook<1>: New Title',
            ...       ' Section<19>: Some Section 0',
            ...       '  ContentNode<20> -> TextBlock<5>: Some TextBlock Name 0',
            ...       '  ContentNode<21> -> LegalDocument<1>: Legal Doc 0',
            ...       '   ContentAnnotation<9>: highlight 0-10',
            ...       '   ContentAnnotation<10>: elide 0-10',
            ...       '  ContentNode<22> -> Link<5>: Some Link Name 0',
            ...       '  Section<23>: Some Section 4',
            ...       '   ContentNode<24> -> TextBlock<6>: Some TextBlock Name 1',
            ...       '   ContentNode<25> -> LegalDocument<2>: Legal Doc 1',
            ...       '    ContentAnnotation<11>: note 0-10',
            ...       '    ContentAnnotation<12>: replace 0-10',
            ...       '   ContentNode<26> -> Link<6>: Some Link Name 1',
            ...       ' Section<27>: Some Section 8',
            ...       ' Section<28>: New Section',
            ...       '  ContentNode<29> -> LegalDocument<3>: Legal Doc 2'
            ... ]
            >>> assert dump_casebook_outline(new_casebook) == expected

            The original copy_of attributes from the published version are preserved:
            >>> full_casebook.refresh_from_db()
            >>> assert original_provenances + [[], []] == [x.provenance for x in full_casebook.contents.all()]

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
        parent.state = Casebook.LifeCycle.PUBLISHED.value

        # update relations
        # draft

        parent.draft = None
        draft.draft = None

        # content nodes

        to_publish = [cn for cn in draft.contents.all().prefetch_resources().prefetch_related('annotations')]
        to_retire = [cn for cn in parent.contents.all().prefetch_resources().prefetch_related('annotations')]
        swap_map = {}
        significant_edits = []
        for content_node in to_publish:
            if content_node.provenance:
                previous_cn = content_node.provenance.pop()
                swap_map[previous_cn] = content_node
            else:
                # If there's no provenance, it's a new node
                if content_node.is_resource:
                    this_edit = CasebookEditLog(casebook=parent, content=content_node, change=CasebookEditLog.ChangeType.ADDED.value)
                    significant_edits.append(this_edit)
            content_node.casebook = parent
        for content_node in to_retire:
            if content_node.id in swap_map:
                original = swap_map.pop(content_node.id)
                content_node.provenance.append(original.id)
                if original.is_resource:
                    if (original.resource_type == 'Link' and original.resource.url != content_node.resource.url) or \
                        (original.resource_type != 'Link' and original.resource.content != content_node.resource.content):
                        this_edit = CasebookEditLog(casebook=parent, content=original, change=CasebookEditLog.ChangeType.EDITED.value)
                        significant_edits.append(this_edit)
                    original_annotations = {(x.global_start_offset, x.global_end_offset, x.content) for x in original.annotations.all()}
                    new_annotations = {(x.global_start_offset, x.global_end_offset, x.content) for x in content_node.annotations.all()}
                    if original_annotations != new_annotations:
                        this_edit = CasebookEditLog(casebook=parent, content=original, change=CasebookEditLog.ChangeType.ANNOTATED.value)
                        significant_edits.append(this_edit)
            else:
                this_edit = CasebookEditLog(casebook=parent, content=content_node, change=CasebookEditLog.ChangeType.REMOVED.value)
                significant_edits.append(this_edit)
            content_node.casebook = draft

        bulk_update_with_history(to_publish + to_retire, ContentNode, ['casebook_id', 'provenance'], batch_size=500, default_change_reason="Draft Merge")
        CasebookEditLog.objects.bulk_create(significant_edits)
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
            ...   '  ContentNode<3> -> LegalDocument<1>: Legal Doc 0',
            ...   '   ContentAnnotation<1>: highlight 0-10',
            ...   '   ContentAnnotation<2>: elide 0-10',
            ...   '  ContentNode<4> -> Link<1>: Some Link Name 0',
            ...   '  Section<5>: Some Section 4',
            ...   '   ContentNode<6> -> TextBlock<2>: Some TextBlock Name 1',
            ...   '   ContentNode<7> -> LegalDocument<2>: Legal Doc 1',
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
            ...      '  ContentNode<12> -> LegalDocument<1>: Legal Doc 0',
            ...      '   ContentAnnotation<5>: highlight 0-10',
            ...      '   ContentAnnotation<6>: elide 0-10',
            ...      '  ContentNode<13> -> Link<3>: Some Link Name 0',
            ...      '  Section<14>: Some Section 4',
            ...      '   ContentNode<15> -> TextBlock<4>: Some TextBlock Name 1',
            ...      '   ContentNode<16> -> LegalDocument<2>: Legal Doc 1',
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
            >>> sonya, elena, john = [User(attribution=name, email_address=f"{name}@scotus.gov") for name in ['Sonya', 'Elena', 'John']]
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
                                               common_title=None,
                                               provenance=self.provenance + [self.id],
                                               draft=None,
                                               state=(Casebook.LifeCycle.DRAFT.value if draft_mode else Casebook.LifeCycle.NEWLY_CLONED.value))
        cloned_casebook.save()

        # If this is a draft, collaborators stay the same,
        # Otherwise, we just add one collaborator (the current_user)
        if draft_mode:
            collaborators = [clone_model_instance(c, casebook=cloned_casebook, can_edit=c.can_edit) for c in
                             self.contentcollaborator_set.all()]
            ContentCollaborator.objects.bulk_create(collaborators) # Currently no History on Collaborators
            self.draft = cloned_casebook
            self.save()
        elif current_user:
            cloned_casebook.add_collaborator(user=current_user, has_attribution=True, can_edit=True)

        cloned_casebook.clone_nodes(old_casebook.contents.prefetch_resources().prefetch_related('annotations')
                                    .select_related('casebook')
                                    .prefetch_related('casebook__contentcollaborator_set'),
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
                                                       old_casebook=None,
                                                       provenance=old_content_node.provenance + [old_content_node.id],
                                                       casebook=self)
            cloned_content_nodes.append(cloned_content_node)

            # clone annotations
            for old_annotation in old_content_node.annotations.all():
                cloned_annotation = clone_model_instance(old_annotation)
                cloned_annotations.append((cloned_annotation, cloned_content_node))

            # clone resources
            if old_content_node.resource_id and old_content_node.resource_type not in {'Case', 'LegalDocument'}:
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
            (ContentNode.objects.filter(casebook_id=self).aggregate(models.Max('ordinals'))['ordinals__max'] or [0])[
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
        uniq = set()
        authors = []
        for collab in self.contentcollaborator_set.order_by('id').all():
            if not collab.has_attribution or collab.user.attribution == 'Anonymous':
                continue
            if collab.user.id not in uniq:
                uniq.add(collab.user.id)
                authors.append(collab.user)
        return authors

    @property
    def has_non_current_authors(self):
        return len(self.non_current_authors) > 0

    @property
    def non_current_authors(self):
        ogs = self.originating_authors
        cgs = self.primary_authors
        return ogs.difference(cgs)

    @property
    def originating_authors(self):
        """
        Every attributed author for any ancestor of a contentnode contained in the section
        """
        originating_node = set([cloned_node for child_content in self.contents.all() for cloned_node in child_content.provenance])
        users = [collaborator.user for cn in
                    ContentNode.objects.filter(id__in=originating_node)
                        .select_related('casebook')
                        .prefetch_related('casebook__contentcollaborator_set__user')
                        .all()
                    for collaborator in cn.casebook.contentcollaborator_set.all() if collaborator.has_attribution and collaborator.user.attribution != 'Anonymous']
        return set(users)

    @property
    def all_collaborators(self):
        return set([c.user for c in self.contentcollaborator_set.all()])

    def followed_by(self, user):
        return user in set(x.user for x in self.casebookfollow_set.all())

    def has_collaborator(self, user):
        # filter in the client to allow .prefetch_related('contentcollaborator_set__user') to work:
        return any(c.user_id == user.id for c in self.contentcollaborator_set.all() if c.can_edit)

    def add_collaborator(self, user, **collaborator_kwargs):
        collaborator_to_add = ContentCollaborator(user=user, casebook_id=self.id, **collaborator_kwargs)
        collaborator_to_add.save()

    def export(self, include_annotations, file_type='docx', export_options=None, docx_footnotes=None):
        """
            Export this node and children as docx, or as html for conversion by pandoc.

            Given:
            >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

            Export uses 8 queries: selecting descendant nodes, and prefetching ContentAnnotation, LegalDocument, TextBlock, and Link, and provenance info.
            >>> with assert_num_queries(select=12, delete=1, insert=1):
            ...     file_data = full_casebook.export(include_annotations=True)
        """
        docx_footnotes = docx_footnotes if docx_footnotes is not None else settings.FORCE_DOCX_FOOTNOTES
        docx_sections = export_options['docx_sections'] if export_options and 'docx_sections' in export_options else settings.FORCE_DOCX_SECTIONS

        # prefetch all child nodes and related data
        if self.export_embargoed() or LiveSettings.load().prevent_exports:
            logger.info(f"Exporting Casebook {self.id}: attempt rejected (too many previous failures)")
            return None
        children = list(self.contents.prefetch_resources().prefetch_related('annotations')) if type(
            self) is not Resource else None

        current_collaborators = set(self.casebook.primary_authors)
        cloned_from = {cn.casebook for cn in self.ancestor_nodes.prefetch_related('casebook')
                                                   .prefetch_related('casebook__contentcollaborator_set')
                                                   .prefetch_related('casebook__contentcollaborator_set__user')
                         if set(cn.casebook.primary_authors) ^ current_collaborators}

        # render html
        logger.info(f"Exporting Casebook {self.id}: serializing to HTML")
        template_name = 'export/casebook.html' if docx_sections else 'export/old_pr1491/casebook.html'

        html = render_to_string(template_name, {
            'is_export': True,
            'node': self,
            'children': children,
            'export_options': export_options,
            'export_date': datetime.now().strftime("%Y-%m-%d"),
            'include_annotations': include_annotations,
            'cloned_from': cloned_from,
        })
        if file_type == 'html':
            return html
        if docx_sections:
            html = html.replace('&nbsp;', ' ').replace('_h2o_keep_element', '&nbsp;').replace('\xa0', ' ')
        if not LiveSettings.export_is_rate_limited():
            return export_via_aws_lambda(self, html, file_type, docx_sections=docx_sections, docx_footnotes=docx_footnotes)
        logger.info(f"Exporting Casebook {self.id} prevented due to rate limits")
        return None

    def inc_export_fails(self):
        # This function is used to avoid making a copy of the casebook via CasebookHistory
        Casebook.objects.filter(id=self.id).update(export_fails= F('export_fails') +1)

    def reset_export_fails(self):
        # This function is used to avoid making a copy of the casebook via CasebookHistory
        Casebook.objects.filter(id=self.id).update(export_fails=0)

    def export_embargoed(self):
        return self.export_fails >= settings.MAX_EXPORT_ATTEMPTS

    @property
    def testing_editor(self):
        """
        Used for testing purposes, return a user that can edit this casebook.
        """
        return ContentCollaborator.objects.filter(can_edit=True, casebook=self).prefetch_related('user').first().user

    def content_tree__load(self):
        ordinal_to_node_map = {}
        top_level_children = []
        for content_node in self.contents.order_by('ordinals').all():
            content_node._content_tree__children = []
            ordinal_to_node_map[content_node.ordinal_coordinate()] = content_node
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
        return [[max([x.ordinals[-1] for x in self.content_tree__children] or [0]) + 1],
                [max([x.display_ordinals[-1] for x in self.content_tree__children] or [0]) + 1]]

    def content_tree__store(self):
        contents = [x for x in self.content_tree__update_ordinals()]
        """
            Update ordinals in the database for any that need to change, based on nodes that have been moved within
            content_tree__children. It is not valid to add nodes from outside, as their tree values will not be populated.
        """
        bulk_update_with_history(contents, ContentNode, ['ordinals', 'display_ordinals'], batch_size=500, default_change_reason="Tree Repair")

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
            >>> new_ordinals = set(casebook.content_tree__update_ordinals())
            >>> assert new_ordinals == {r_1_3, s_1_4, r_1_4_2, r_1_4_3, r_1_4_1}
        """
        current_display_ordinal = 0
        for i, node in enumerate(self.content_tree__children):
            correct_ordinals = [i + 1]
            if node.does_display_ordinals:
                current_display_ordinal += 1
            if node.ordinals != correct_ordinals or not(node.display_ordinals) or node.display_ordinals[-1] != current_display_ordinal:
                node.ordinals = correct_ordinals
                node.display_ordinals = [current_display_ordinal]
                yield node
            if node.content_tree__children:
                yield from node.content_tree__update_ordinals()

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
            Casebook.LifeCycle.REVISING.value: 'casebook-public',
            Casebook.LifeCycle.PREVIOUS_SAVE.value: 'casebook-archived'
        }[self.state]

    def tabs_for_user(self, user, current_tab=None):
        read_tab = 'Preview' if self.in_edit_state else 'Casebook'
        if current_tab is None:
            current_tab = read_tab
        tabs = [('Edit', reverse('edit_casebook', args=[self]), self.in_edit_state and self.editable_by(user)),
                (read_tab, reverse('casebook', args=[self]), not self.is_archived),
                ('Credits', reverse('show_credits', args=[self]), not self.is_archived),
                ('Related', reverse('show_related', args=[self]), not self.is_archived and user.is_superuser),
                ('History', reverse('casebook_history', args=[self]), self.viewable_by(user)),
                ('Settings', reverse('casebook_settings', args=[self]), self.editable_by(user))]
        return [(n, l, n == current_tab) for n,l,c in tabs if c]

    @property
    def revising(self):
        return self.draft_of

    @property
    def grouped_edit_log(self):
        def change_priority(entry):
            return [CasebookEditLog.ChangeType.ORIGINAL_PUBLISH.value,
                    CasebookEditLog.ChangeType.ADDED.value,
                    CasebookEditLog.ChangeType.REMOVED.value,
                    CasebookEditLog.ChangeType.EDITED.value,
                    CasebookEditLog.ChangeType.ANNOTATED.value].index(entry.change)

        qs = self.edit_log.order_by('-entry_date')
        last_date = (None, None, None)
        results = []
        log_line = {}
        for entry in qs.all():
            current_date = (entry.entry_date.year, entry.entry_date.month, entry.entry_date.day)
            if last_date == (None,None,None):
                last_date = current_date
            if current_date != last_date:
                results.append(list(log_line.values()))
                log_line = {}
                last_date = current_date
            current_entry = log_line.get(entry.content and entry.content.title, None)
            if not current_entry:
                log_line[entry.content and entry.content.title] = entry
            elif current_entry.change == CasebookEditLog.ChangeType.REMOVED.value and entry.change == CasebookEditLog.ChangeType.ADDED.value:
                log_line.pop(entry.content and entry.content.title)
            else:
                log_line[entry.content and entry.content.title] = min([current_entry,entry], key=change_priority)
        results.append(list(log_line.values()))
        return results
