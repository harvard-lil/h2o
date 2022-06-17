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
            raise ValueError(f"{field_name} is not in tracked_fields")
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
        >>> caplog.clear()
        >>> with caplog.at_level(logging.DEBUG):
        ...     cleanse_html_field(node, 'headnote')
        >>> assert len(caplog.record_tuples) == 2
        >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in ContentNode headnote'
        >>> assert caplog.record_tuples[1][2] == 'Stripping trailing whitespace in ContentNode headnote'
        >>> assert node.headnote == same_after_sanitizing
        >>> caplog.clear()

        Optionally, sanitize the field to remove potentially dangerous HTML before cleaning up whitespace:
        >>> node.headnote = same_after_cleansing
        >>> caplog.clear()
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
        >>> caplog.clear()
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
                         f"Normalizing newlines in {type(model_instance).__name__} {fieldname}")
    if sanitize_field:
        run_if_field_changed(sanitize, f"Sanitizing {type(model_instance).__name__} {fieldname}")
    run_if_field_changed(strip_trailing_block_level_whitespace,
                         f"Stripping trailing whitespace in {type(model_instance).__name__} {fieldname}")


class AnnotatedModel(EditTrackedModel):
    """
        Abstract base class for LegalDocument and TextBlock resource types, which can be annotated. Ensures that annotation
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
            logger.debug(f"Updating annotations for {type(self).__name__}")
            ContentAnnotation.update_annotations(self.related_annotations(), self.original_state['content'],
                                                 self.content)
        super().save(*args, **kwargs)

#
# Models
#


#
# Legal Doc Source Types
#

vs_check = re.compile(" [vV][sS]?[.]? ")
def truncate_name(case_name):
    max_part_length = 40
    parts = vs_check.split(case_name)
    if len(parts) != 2:
        return case_name[:max_part_length * 2 + 4] + ("..." if len(case_name) > (max_part_length * 2 + 4) else "")
    part_a = parts[0][:max_part_length] + ("..." if len(parts[0]) > max_part_length else "")
    part_b = parts[1][:max_part_length] + ("..." if len(parts[1]) > max_part_length else "")
    return part_a + " v. " + part_b



class CAP:
    details = {'name': 'CAP',
               'short_description':'CAP provides US Case law up to 2018',
               'long_description':'The Caselaw Access Project contains three hundred and sixty years of United States caselaw',
               'link':'https://case.law/',
               'search_regexes': [
                   {'name': 'US Case Law',
                    'regex':r'\b[0-9]+ (?:[0-9A-Z][0-9a-z.]*[ .])+[0-9]+\b'},
                   {'name': 'US Case Law',
                    'regex':'https://cite.case.law/.*'},
                   {'name': 'US Case Law',
                    'regex':r'( vs?[.]? )|(\bin re:\b)|(ex parte)',
                    'fuzzy': True},
               ],
               'footnote_regexes': [
                    # these are identical, except they order the html attributes differently
                    r'<a id="ref_footnote_[\d]+_[\d]+" class="footnotemark" href="#footnote_[\d]+_[\d]+">.*<aside',
                    r'<a class="footnotemark" href="#footnote_[\d]+_[\d]+" id="ref_footnote_[\d]+_[\d]+">.*<aside'
               ]
    }

    @staticmethod
    def convert_search_result(result):
        cites = [x['cite'] for x in result['citations'] if x['type'] == 'official'] + \
                [x['cite'] for x in result['citations'] if x['type'] != 'official']
        return {
            'fullName':result.get('name', result.get('name_abbreviation', '')),
            'shortName': truncate_name(result.get('name_abbreviation', result.get('name', ''))),
            'fullCitations': ', '.join(cites),
            'shortCitations': ', '.join(cites[:3]) + ("..." if len(cites) > 3 else ""),
            'effectiveDate': result.get('decision_date', None),
            'url': result.get('frontend_url', None),
            'id': result.get('id', None)
        }


    @staticmethod
    def looks_like_url(query):
        return looks_like_case_law_link(query)

    @staticmethod
    def convert_frontend_url(url):
        frontend_url = url.split('cite.case.law')[1]
        frontend_split = frontend_url[1:-1].split("/")
        # https://github.com/harvard-lil/capstone/blob/fe072badff59c4127d2ce82a557b287aaefc79f0/capstone/cite/urls.py#L14
        if len(frontend_split) == 4:
            id = frontend_split[-1]
            return {'id': id}
        elif len(frontend_split) == 3:
            reporter, volume, page = frontend_split
            citation = f"{volume} {reporter.replace('-', ' ')} {page}"
            return {'cite': citation}
        return {'frontend_url': frontend_url}

    @staticmethod
    def cap_params(search_params):
        if search_params.q:
            query = search_params.q.replace('’',"'")
            if looks_like_case_law_link(query):
                return CAP.convert_frontend_url(query)
            elif looks_like_citation(query):
                return {'cite': query}

        params = {'name_abbreviation': search_params.name if search_params.name else search_params.q,
                'cite': search_params.citation,
                'decision_date_max': search_params.before_date,
                'decision_date_min': search_params.after_date,
                'jurisdiction': search_params.jurisdiction}
        return {k:params[k] for k in params.keys() if params[k] is not None}

    @staticmethod
    def search(search_params):
        param_defaults = {'page_size': 30, 'ordering': '-analysis.pagerank.percentile'}
        # In some cases, cap search will return too many results for what should be a unique search by frontend_urls
        supplied_cap_params = CAP.cap_params(search_params)
        cap_params = {**param_defaults, **supplied_cap_params}
        response = requests.get(settings.CAPAPI_BASE_URL + "cases/", cap_params)
        try:
            results = response.json()['results']
        except Exception:
            results = []
        return [CAP.convert_search_result(x) for x in results]

    @staticmethod
    def preprocess_body(body):
        return body

    @staticmethod
    def postprocess_content(body, postfix_id, export_options=None):
        def style_page_no(_, pn):
            pn.attrib['data-custom-style'] = 'Page Number'
            pn.addprevious(lxml.etree.XML('<span> </span>'))
            pn.addnext(lxml.etree.XML('<span> </span>'))

        def unlink_page_nos(_, page_no):
            page_no.tag = 'span'
            page_no.attrib['data-custom-style'] = 'Page Number'

        body_parsed = PyQuery(body)
        # Footnotes
        for aside in body_parsed('aside.footnote').filter(lambda _, this: len(PyQuery(this).children()) > 1).items():
            link, first_p = [PyQuery(x) for x in aside.children()[:2]]
            first_p.html(link.outer_html() + first_p.html())
            link.remove()
            footnote_text_style = "Case Footnote Text" + (f"-{postfix_id}" if export_options and export_options.get('docx_footnotes', False) else "")
            aside.wrap(f'<div data-custom-style="{footnote_text_style}"></div>')

        for mark in body_parsed('.footnotemark').items():
            # Can't just use wrap here, because it grabs some of the surrounding text
            # This also inverts the tags, so the span appears inside the a tag
            # ¯\_(ツ)_/¯

            footnote_style = "Case Footnote Reference" + (f"-{postfix_id}" if export_options and export_options.get('docx_footnotes', False) else "")
            mark.html(f'<span data-custom-style="{footnote_style}">{mark.html()}</span>')

        # Page nos
        body_parsed('.page-label').remove()

        # vanillify citation links
        for link in body_parsed('a.citation'):
            link.tag = "span"

        # Case Header styling
        # for pq in body_parsed('section.head-matter p, center, p[style="text-align:center"], p[align="center"]').items():
        #     pq.wrap("<div data-custom-style='Case Header'></div>")
        for el in body_parsed('section.head-matter h4, center h2, h2[style="text-align:center"], h2[align="center"]'):
            el.tag = 'div'
            el.attrib['data-custom-style'] = 'Case Header'
        # From cases.scss

        hidden_classes = ['.parties', '.decisiondate', '.docketnumber', '.citations', '.syllabus', '.synopsis', '.court']
        for hide_class in hidden_classes:
            body_parsed.remove(hide_class)

        body_parsed('em [data-custom-style]').add_class('popup_raiser')

        pop_target = '<span data-custom-style="Elision" class="popup_raiser">[ … ]</span>'
        dumped_html = body_parsed.html().replace(pop_target, f"</em>{pop_target}<em>")
        return f'<div data-custom-style="Case Body">{dumped_html}</div>'

    @staticmethod
    def pull(legal_doc_source, id):
        if not settings.CAPAPI_API_KEY:
            raise APICommunicationError('To interact with CAP, CAPAPI_API_KEY must be set.')
        try:
            response = requests.get(
                settings.CAPAPI_BASE_URL + f"cases/{id}/",
                {"full_case": "true", "body_format": "html"},
                headers={'Authorization': f'Token {settings.CAPAPI_API_KEY}'}
            )
            assert response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with CAPAPI failed: {str(e)}"
            raise APICommunicationError(msg)

        metadata = response.json()
        body = CAP.preprocess_body(metadata.pop('casebody', {}).pop('data',None))
        citations = [x.get('cite') for x in metadata.get('citations', []) if 'cite' in x]

        # annotate metadata with details about the case's HTML, for convenience
        metadata['html_info'] = {'source': 'cap'}
        for regex in CAP.details['footnote_regexes']:
            if re.search(regex, body, re.DOTALL):
                metadata['html_info']['footnotes'] = {
                    'style': 'cap',
                    'regex': regex,
                    'last_checked_timestamp': datetime.now().timestamp()
                }
                break
        case = LegalDocument(source=legal_doc_source,
                             short_name=metadata.get('name_abbreviation'),
                             name=metadata.get('name'),
                             doc_class='Case',
                             citations=citations,
                             jurisdiction=metadata.get('jurisdiction', {}).get('slug', ''),
                             effective_date=parser.parse(metadata.get('decision_date')),
                             publication_date=parser.parse(metadata.get('last_updated')),
                             updated_date=datetime.now(),
                             source_ref=str(id),
                             content=body,
                             metadata=metadata)
        return case

    @staticmethod
    def get_metadata(id):
        try:
            response = requests.get(
                settings.CAPAPI_BASE_URL + f"cases/{id}/",
                {}
            )
            assert response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with CAPAPI failed: {str(e)}"
            raise APICommunicationError(msg)

        metadata = response.json()
        citations = [x.get('cite') for x in metadata['citations'] if 'cite' in x]
        data = {
                'short_name'       : metadata.get('name_abbreviation'),
                'name'             : metadata.get('name'),
                'doc_class'        : 'Case',
                'citations'        : citations,
                'jurisdiction'     : metadata.get('jurisdiction', {}).get('slug', ''),
                'effective_date'   : parser.parse(metadata.get('decision_date')),
                'publication_date' : parser.parse(metadata.get('last_updated')),
                'updated_date'     : datetime.now(),
                'source_ref'       : str(id),
                'metadata'         : metadata}
        return data

    @staticmethod
    def header_template(legal_document):
        return 'cap_header.html'

class USCodeGPO():
    details = {'name': 'GPO',
               'short_description':'The GPO provides the USCode',
               'long_description':'The GPO provides section level access to the US Code',
               'link':'https://www.govinfo.gov/app/collection/uscode',
               'search_regexes': [
                   {'name': 'US Code',
                    'regex': '[0-9]* U[.]?S[.]?C[.]? §§? ?[0-9]*(-[0-9]*)?'
                   },
                   {'name':'US Code',
                    'regex':'https://www.law.cornell.edu/uscode/.*'
                   }
               ],
               'footnote_regexes': []
    }

    @staticmethod
    def convert_search_result(result):
        # convert search results to the format the FE expects
        return {
            'fullName':result.title,
            'shortName': truncate_name(result.title),
            'fullCitations': result.citation,
            'shortCitations': result.citation,
            'effectiveDate': result.effective_date,
            'url': result.gpo_url,
            'id': result.gpo_id
        }


    @staticmethod
    def looks_like_url(query):
        # t/f for looking like GPO/LII url
        lii_matcher = re.compile("https://www.law.cornell.edu/uscode/text/[0-9]*/[0-9]*")
        return lii_matcher.match(query)

    @staticmethod
    def convert_frontend_url(url):
        # Convert url to query
        return {}

    @staticmethod
    def search(search_params):
        # given standard search params return results
        abbreviator = re.compile(r'\bUSC\b', re.IGNORECASE)
        silcrow_spacer = re.compile(r'§([0-9])')
        query = None
        if search_params.q:
            search_params.q = re.sub(abbreviator, 'U.S.C.', search_params.q)
            search_params.q = silcrow_spacer.sub(r'§ \1', search_params.q)
        cite_matcher = re.compile('[0-9]+ U.S.C. § ?[0-9]+(-[0-9]+)?')
        if cite_matcher.match(search_params.q):
            search_params.citation = search_params.q
            query = SearchQuery(search_params.citation)
            search_params.q = None
        search_fields = {}
        if search_params.before_date:
            search_fields['effective_date__lte'] = search_params.before_date
        if search_params.after_date:
            search_fields['effective_date__gte'] = search_params.after_date
        if search_params.citation:
            search_fields['citation'] = search_params.citation
        if search_params.frontend_url:
            search_fields['lii_url'] = search_params.frontend_url
        if search_params.q:
            if USCodeGPO.looks_like_url(search_params.q):
                search_fields['lii_url'] = search_params.q
            query = SearchQuery(search_params.q, config='english')
            search_fields['search_field'] = query

        vector = SearchVector('citation', config='english', weight='A') + SearchVector('title', config='english', weight='B')
        return [USCodeGPO.convert_search_result(x) for x in USCodeIndex.objects.filter(**search_fields).annotate(rank=SearchRank(vector, query)).order_by('repealed', '-rank')[:30]]

    @staticmethod
    def parse_gpo_html(full_body):
        any_field = re.compile('<!-- *field-(?P<field>(?:start|end):[^ ]+) *-->')
        br = re.compile('<br */>')
        comment = re.compile('<!-- .* -->')

        def get_field(field_name, text, start_loc= 0):
            start = re.compile(f'<!-- *field-start:{field_name} *-->')
            end = re.compile(f'<!-- *field-end:{field_name} *-->')
            start_match = start.search(text, start_loc)
            if not start_match:
                return {'start':None, 'end':None,'content':None}
            end_matches = [x.span()[1] for x in end.finditer(text, start_match.span()[1])]
            if not end_matches:
                return {'start':None,'end':None,'content':None}
            field_range = (start_match.span()[0],end_matches[-1])
            return {'start':field_range[0],
                    'end':field_range[1],
                    'content':text[field_range[0]:field_range[1]]}

        def strip_brs(text):
            return br.sub('',text)

        def span_contents(text):
            return [x.text for x in PyQuery(text)("span") if x.text]

        def strip_comments(text):
            return comment.sub('', text)

        def parse(text):
            full_body = PyQuery(text)("body").html()
            q = any_field.search(full_body)
            header_section = full_body[:q.span()[0]]
            header_lines = span_contents(header_section)
            statute_body = get_field('statute', full_body)
            notes_start = statute_body['end'] or 0
            notes = get_field('notes', full_body, notes_start)
            return {'header': header_lines,
                    'body': strip_comments(strip_brs(statute_body['content'])) if statute_body['content'] else '' ,
                    'notes': strip_comments(strip_brs(notes['content'])) if notes['content'] else ''}

        parts = parse(full_body)
        parts['combined_body'] = (parts['body'] or '') + ('\n<h4 class="notes-section">Notes</h4>\n' + parts['notes']) if parts['notes'] else ''
        return parts


    @staticmethod
    def pull(legal_doc_source, id):
        # given a source_ref/API id return an (unsaved) LegalDocument
        if not settings.GPO_API_KEY:
            raise APICommunicationError('To interact with the GPO API, a key must be set.')
        try:
            package_id = "-".join(id.split("-")[:3])
            body_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/htm",
                {},
                headers={'X-Api-Key': settings.GPO_API_KEY},
            )
            assert body_response.ok
            metadata_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/summary",
                {},
                headers={'X-Api-Key': settings.GPO_API_KEY},
            )
            assert metadata_response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with GPO API failed: {str(e)}"
            raise APICommunicationError(msg)
        metadata = metadata_response.json()

        content = PyQuery(body_response.content)

        effective_date = parser.parse(metadata['dateIssued'])
        publication_date = parser.parse(metadata['lastModified'])
        title_no = id.split("-")[2][5:]
        first_section = metadata['leafRange']['from']
        last_section = metadata['leafRange']['to']
        single_leaf = first_section == last_section
        silcrow = '§' if single_leaf else '§§'
        sections = first_section if single_leaf else first_section + '-' + last_section
        citation = f"{title_no} U.S.C. {silcrow} {sections}"

        parsed_body = USCodeGPO.parse_gpo_html(content)
        metadata['header'] = parsed_body['header']
        formatted_body = parsed_body['combined_body']
        code = LegalDocument(source=legal_doc_source,
                             name=metadata['title'],
                             doc_class='Code',
                             citations=[citation],
                             effective_date=effective_date,
                             publication_date=publication_date,
                             updated_date=datetime.now(),
                             source_ref=id,
                             content=formatted_body,
                             metadata=metadata)
        return code

    @staticmethod
    def get_metadata(id):
        # given a source_ref/API id return an (unsaved) LegalDocument
        if not settings.GPO_API_KEY:
            raise APICommunicationError('To interact with the GPO API, a key must be set.')
        try:
            package_id = "-".join(id.split("-")[:3])
            body_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/htm",
                {},
                headers={'X-Api-Key': settings.GPO_API_KEY},
            )
            assert body_response.ok
            metadata_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/summary",
                {},
                headers={'X-Api-Key': settings.GPO_API_KEY},
            )
            assert metadata_response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with GPO API failed: {str(e)}"
            raise APICommunicationError(msg)
        metadata = metadata_response.json()

        content = PyQuery(body_response.content)

        effective_date = parser.parse(metadata['dateIssued'])
        publication_date = parser.parse(metadata['lastModified'])
        title_no = id.split("-")[2][5:]
        first_section = metadata['leafRange']['from']
        last_section = metadata['leafRange']['to']
        single_leaf = first_section == last_section
        silcrow = '§' if single_leaf else '§§'
        sections = first_section if single_leaf else first_section + '-' + last_section
        citation = f"{title_no} U.S.C. {silcrow} {sections}"

        parsed_body = USCodeGPO.parse_gpo_html(content)
        metadata['header'] = parsed_body['header']
        code = {
                'name'             : metadata['title'],
                'doc_class'        : 'Code',
                'citations'        : [citation],
                'effective_date'   : effective_date,
                'publication_date' : publication_date,
                'updated_date'     : datetime.now(),
                'source_ref'       : id,
                'metadata'         : metadata}
        return code

    @staticmethod
    def header_template(legal_document):
        return 'gpo_header.html'


class LegacyNoSearch():
    details = {'name': 'LegacyDocument',
               'short_description':'ERROR',
               'long_description':'ERROR',
               'link':'ERROR',
               'search_regexes': [],
               'footnote_regexes': []}

    @staticmethod
    def search(search_params):
        return []

    @staticmethod
    def pull(legal_doc_source, id):
        return None

    @staticmethod
    def header_template(legal_document):
        return 'empty_header.html'


def get_display_name_field(category):
    display_name_fields = {
        'legal_doc': 'display_name',
        'casebook': 'title',
        'user': 'attribution'
    }
    return f'metadata__{display_name_fields[category]}'


def dump_search_results(parts):
    results, counts, facets = parts
    return ([{k: '...' if k == 'created_at' else v for k, v in r.metadata.items()} for r in results.object_list], counts, facets)


class SearchIndex(models.Model):
    result_id = models.IntegerField()
    document = SearchVectorField()
    metadata = JSONField()
    category = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = 'internal_search_view'

    @classmethod
    def create_search_index(cls):
        """ Create or replace the materialized view 'search_view', which backs this model """
        with connection.cursor() as cursor:
            cursor.execute(Path(__file__).parent.joinpath('create_search_index.sql').read_text())

    @classmethod
    def refresh_search_index(cls):
        """ Refresh the contents of the materialized view """
        with connection.cursor() as cursor:
            try:
                cursor.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY internal_search_view")
            except ProgrammingError as e:
                if e.args[0].startswith('relation "internal_search_view" does not exist'):
                    cls.create_search_index()

    @classmethod
    def search(cls, *args, **kwargs):
        try:
            return cls._search(*args, **kwargs)
        except ProgrammingError as e:
            if e.args[0].startswith('relation "internalsearch_view" does not exist'):
                cls.create_search_index()
                return cls._search(*args, **kwargs)
            raise

    @classmethod
    def _search(cls, category, query=None, page_size=10, page=1, filters={}, facet_fields=[], order_by=None):
        """
        Given:
        >>> _, legal_document_factory, casebook_factory = [getfixture(i) for i in ['reset_sequences', 'legal_document_factory', 'casebook_factory']]
        >>> casebooks = [casebook_factory() for i in range(3)]
        >>> users = [cc.user for cb in casebooks for cc in cb.contentcollaborator_set.all() ]
        >>> docs = [legal_document_factory() for i in range(3)]
        >>> SearchIndex().create_search_index()

        Get all casebooks:
        >>> assert dump_search_results(SearchIndex().search('casebook')) == (
        ...     [
        ...         {'affiliation': 'Affiliation 0', 'created_at': '...', 'title': 'Some Title 0', 'attribution': 'Some User 0'},
        ...         {'affiliation': 'Affiliation 1', 'created_at': '...', 'title': 'Some Title 1', 'attribution': 'Some User 1'},
        ...         {'affiliation': 'Affiliation 2', 'created_at': '...', 'title': 'Some Title 2', 'attribution': 'Some User 2'}
        ...     ],
        ...     {'user': 3, 'legal_doc': 3, 'casebook': 3},
        ...     {}
        ... )

        Get casebooks by query string:
        >>> assert dump_search_results(SearchIndex().search('casebook', 'Some Title 0'))[0] == [
        ...     {'affiliation': 'Affiliation 0', 'created_at': '...', 'title': 'Some Title 0', 'attribution': 'Some User 0'},
        ... ]

        Get casebooks by filter field:
        >>> assert dump_search_results(SearchIndex().search('casebook', filters={'attribution': 'Some User 1'}))[0] == [
        ...     {'affiliation': 'Affiliation 1', 'created_at': '...', 'title': 'Some Title 1', 'attribution': 'Some User 1'},
        ... ]

        Get all users:
        >>> assert dump_search_results(SearchIndex().search('user')) == (
        ...     [
        ...         {'casebook_count': 1, 'attribution': 'Some User 0', 'affiliation': 'Affiliation 0'},
        ...         {'casebook_count': 1, 'attribution': 'Some User 1', 'affiliation': 'Affiliation 1'},
        ...         {'casebook_count': 1, 'attribution': 'Some User 2', 'affiliation': 'Affiliation 2'},
        ...     ],
        ...     {'casebook': 3, 'legal_doc': 3, 'user': 3},
        ...     {},
        ... )

        Get all cases:
        >>> assert dump_search_results(SearchIndex().search('legal_doc')) == (
        ...     [
        ...         {'citations': 'Adventures in criminality, 1 Fake 1, (2001)', 'display_name': 'Legal Doc 0', 'jurisdiction': None, 'effective_date': '1900-01-01T00:00:00+00:00', 'effective_date_formatted': 'January   1, 1900'},
        ...         {'citations': 'Adventures in criminality, 1 Fake 1, (2001)', 'display_name': 'Legal Doc 1', 'jurisdiction': None, 'effective_date': '1900-01-01T00:00:00+00:00', 'effective_date_formatted': 'January   1, 1900'},
        ...         {'citations': 'Adventures in criminality, 1 Fake 1, (2001)', 'display_name': 'Legal Doc 2', 'jurisdiction': None, 'effective_date': '1900-01-01T00:00:00+00:00', 'effective_date_formatted': 'January   1, 1900'}
        ...     ],
        ...     {'legal_doc': 3, 'user': 3, 'casebook': 3},
        ...     {}
        ... )
        """
        base_query = cls.objects.all()
        query_vector = SearchQuery(query, config='english') if query else None
        if query_vector:
            base_query = base_query.filter(document=query_vector)
        for k, v in filters.items():
            base_query = base_query.filter(**{f'metadata__{k}': v})

        # get results
        results = base_query.filter(category=category).only('result_id', 'metadata')
        if query_vector:
            results = results.annotate(rank=SearchRank(F('document'), query_vector))

        display_name = get_display_name_field(category)
        order_by_expression = [display_name]
        if order_by:
            # Treat 'decision date' like 'created at', so that sort-by-date is maintained
            # when switching between case and casebook tab.
            fix_after_rails('consider renaming these params "date".')
            if query and order_by == 'score':
                order_by_expression = ['-rank', display_name]
            elif category == 'casebook':
                if order_by in ['created_at', 'effective_date']:
                    order_by_expression = ['-metadata__created_at', display_name]
            elif category == 'case':
                if order_by in ['created_at', 'effective_date']:
                    order_by_expression = ['-metadata__effective_date', display_name]

        results = results.order_by(*order_by_expression)
        results = Paginator(results, page_size).get_page(page)

        # get counts
        counts = {c['category']: c['total'] for c in base_query.values('category').annotate(total=Count('category'))}
        results.__dict__['count'] = counts.get(category, 0)  # hack to avoid redundant query for count

        # get facets
        facets = {}
        for facet in facet_fields:
            facet_param = f'metadata__{facet}'
            facets[facet] = base_query.filter(category=category).exclude(**{facet_param: ''}).order_by(facet_param).values_list(facet_param, flat=True).distinct()

        return results, counts, facets

class USCodeIndex(models.Model):
    title = models.CharField(max_length=1000)
    gpo_id = models.CharField(max_length=255)
    citation = models.CharField(max_length=255)
    lii_url = models.URLField(null=True)
    gpo_url = models.URLField(null=True)
    effective_date = models.DateField(blank=True, null=True)
    search_field = SearchVectorField(null=True)
    repealed = models.BooleanField(null=True)

    def save(self, *args, **kwargs):
        self.search_field = (SearchVector('citation', weight='A')
                             + SearchVector('title', weight='B'))
        super().save(*args, **kwargs)


class LegalDocumentSource(models.Model):
    name = models.CharField(max_length=10000, blank=True, null=True)
    date_added = models.DateField(blank=True, null=True)
    last_updated = models.DateField(blank=True, null=True)
    active = models.BooleanField(default=False)
    priority = models.IntegerField(null=True)
    search_class = models.CharField(max_length=100, blank=True, null=True)
    short_description = models.CharField(max_length=140, blank=True, null=True)

    source_apis = {}

    class Meta:
        ordering = ['priority']

    @classmethod
    def register_api(cls, api):
        if api.details['name'] not in cls.source_apis:
            cls.source_apis[api.details['name']] = api

    def api_model(self):
        # short_description, long_description, bulk_process, search(long_citation_json), import(id)
        if self.search_class in self.source_apis:
            return self.source_apis[self.search_class]
        raise ValueError(f"Missing API Model for {self.name}")

    def get_metadata(self, id):
        api_model = self.api_model()
        return (hasattr(api_model, 'get_metadata') and api_model.get_metadata(id)) or None

    def pull(self, id):
        return self.api_model().pull(self, id)

    def most_recent_with_id(self, id):
        return LegalDocument.objects.filter(source=self, source_ref=id).order_by('-effective_date','-publication_date').first()


LegalDocumentSource.register_api(USCodeGPO)
LegalDocumentSource.register_api(CAP)
LegalDocumentSource.register_api(LegacyNoSearch)

class LegalDocument(NullableTimestampedModel, AnnotatedModel):
    source = models.ForeignKey('LegalDocumentSource', on_delete='DO_NOTHING', related_name='documents')
    short_name = models.CharField(max_length=150, blank=True, null=True)
    name = models.CharField(max_length=10000, blank=True, null=True)
    # The type of document: Case, Regulation, Code, Bill, etc.
    doc_class = models.CharField(max_length=100, blank=True, null=True)
    citations = ArrayField(models.CharField(max_length=500, blank=True, null=True))
    # list of jurisdictions is currently in CaseSearcher.vue (room for improvement)
    jurisdiction = models.CharField(max_length=20, blank=True, null=True)
    # I think a tritemporal model is as simple as I can deal make this
    # When the document was made effective (may be before or after other dates)
    effective_date = models.DateTimeField(blank=True, null=True)
    # When the DB 'published'
    publication_date = models.DateTimeField(blank=True, null=True)
    # When this copy was pulled from the external source
    updated_date = models.DateTimeField(blank=True, null=True)
    source_ref = models.CharField(max_length=10000)
    content = models.CharField(max_length=5242880)
    metadata = JSONField(blank=True, null=True)
    history = HistoricalRecords()

    class Meta:
        indexes = [
            GinIndex(fields=['citations']),
        ]

    @property
    def header_template(self):
        base = 'includes/legal_doc_sources/'
        template = self.source.api_model().header_template(self)
        return base + template

    def save(self, *args, **kwargs):
        r"""
            Override save to ensure Case HTML is cleansed and annotations are
            repositioned on save.

            Given:
            >>> annotations_factory, caplog = [getfixture(f) for f in ['annotations_factory', 'caplog']]
            >>> html_with_annotations =     '<p>\n  <em>[note]Keep foo[/note] [highlight]delete bar[/highlight] [elide]keep baz[/elide] buzz</em>\n</p><p>bam</p>'
            >>> new_html =                  '<p>Prepended</p>\n\n<p>\n  <em invalid-attr="invalid">Keep foo <invalid>keep baz</invalid> buzz add boo</em>\n</p>'
            >>> new_doc_html_with_annotations = '<p>Prepended</p><p>\n  <em invalid-attr="invalid">[note]Keep foo[/note] <invalid>[elide]keep baz</invalid>[/elide] buzz add boo</em>\n</p>'

            On save, Case HTML is cleansed (but not sanitized), and then annotations are updated:
            >>> _, legal_doc = annotations_factory('LegalDocument', html_with_annotations)
            >>> legal_doc.resource.content = new_html
            >>> caplog.clear()
            >>> with caplog.at_level(logging.DEBUG):
            ...     legal_doc.resource.save()
            >>> assert dump_annotated_text(legal_doc) == new_doc_html_with_annotations
            >>> assert len(caplog.record_tuples) == 3
            >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in LegalDocument content'
            >>> assert caplog.record_tuples[1][2] == 'Stripping trailing whitespace in LegalDocument content'
            >>> assert caplog.record_tuples[2][2] == 'Updating annotations for LegalDocument'
        """
        cleanse_html_field(self, 'content')
        super().save(*args, **kwargs)

    @property
    def get_title(self):
        return self.short_name or self.name

    def get_name(self):
        return self.short_name or self.name

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type='LegalDocument')

    @property
    def cite_string(self):
        return ", ".join(self.citations)

    # Utility functions

    def has_newer_version(self):
        if self.source.name == 'Legacy':
            return False
        latest_downloaded = self.source.most_recent_with_id(self.source_ref)
        if latest_downloaded.publication_date > self.publication_date:
            return True
        latest_meta = self.source.get_metadata(self.source_ref)
        return latest_meta and latest_meta['publication_date'] > timezone.utc.localize(self.publication_date)

    def get_latest_version(self, only_local=False):
        latest_version = self.source.most_recent_with_id(self.source_ref) if only_local else self.source.pull(self.source_ref)
        if latest_version.publication_date <= timezone.utc.localize(self.publication_date):
            return self
        return latest_version

    def has_bad_footnotes(self):
        pq = PyQuery(self.content)
        self_links = [a for a in pq('a') if a.attrib.get('href', '').startswith('#')]
        for sl in self_links:
            target_id = sl.attrib.get('href')[1:]
            if not pq(f'[id="{target_id}"]'):
                return True
        return False



class ContentAnnotationQueryset(models.QuerySet):
    def valid(self):
        """
            Return annotations excluding those that were marked invalid when shifting.
        """
        return self.exclude(global_start_offset=-1, global_end_offset=-1)


class ContentAnnotation(TimestampedModel, BigPkModel):
    kind = models.CharField(max_length=255, choices=(
        ('replace', 'replace'), ('highlight', 'highlight'), ('elide', 'elide'), ('note', 'note'), ('link', 'link'), ('correction','correction')))
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
        content = f" with {truncatechars(self.content, 20)}" if self.content else ""
        return f"{self.kind} {self.global_start_offset}-{self.global_end_offset}{content}"

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

class CasebookFollow(TimestampedModel, BigPkModel):
    user = models.ForeignKey('User',
                             on_delete=models.CASCADE,
                             )
    casebook = models.ForeignKey(
        'Casebook',
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True
    )
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


class ContentNodeQueryset(models.QuerySet):
    """
        This queryset allows us to do ContentNode.objects.prefetch_resources() so that fetched content nodes will
        efficiently have their content_node.resource attribute pre-populated, using a total of three queries instead
        of one query per instance. This is based on the implementation of prefetch_related().

        Given:
        >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]
        >>> section = ContentNode.objects.filter(casebook=full_casebook).first()

        Fetching all resources normally will take a linear number of queries -- each c.resource hits the DB:
    """

    # keep track of input values from prefetch_resources()
    _prefetch_resources_done = False
    _prefetch_resources = None

    def prefetch_resources(self, textblock_query=None, link_query=None, legal_doc_query=None):
        """
            Return cloned queryset with attributes to trigger prefetching in _fetch_all.
        """
        clone = self._chain()
        clone._prefetch_resources = [textblock_query, link_query, legal_doc_query]
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
            textblock_query, link_query, legal_doc_query = self._prefetch_resources
            if textblock_query is None:
                textblock_query = TextBlock.objects.all()
            if link_query is None:
                link_query = Link.objects.all()
            if legal_doc_query is None:
                legal_doc_query = LegalDocument.objects.all()
            resources = {}
            for resource_type, query in (('TextBlock', textblock_query), ('Link', link_query), ('LegalDocument', legal_doc_query)):
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
    display_ordinals = ArrayField(models.IntegerField(), default=list)
    does_display_ordinals = models.BooleanField(default=True)

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
        next_ordinal = prefix + [max([x.ordinals[-1] for x in self.content_tree__children] or [0]) + 1]
        next_display_ordinal = prefix + [max([x.ordinals[-1] for x in self.content_tree__children if x.does_display_ordinals] or [0]) + 1]
        return [next_ordinal, next_display_ordinal]

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
            >>> with assert_raises(ValueError, match='Cannot move node to root'):
            ...     s_1.content_tree__move_to([])
            >>> with assert_raises(ValueError, match='Cannot add descendant of Resource'):
            ...     r_1_4_2.content_tree__move_to([1, 1, 1])
            >>> with assert_raises(ValueError, match='Cannot move a node inside itself'):
            ...     s_1.content_tree__move_to([1, 1, 1])

            Move a node to the top level of the casebook:
            >>> r_1_4_3.refresh_from_db()
            >>> r_1_4_3.content_tree__move_to([1])
            >>> casebook.refresh_from_db()
            >>> assert dump_content_tree(casebook)[0] == [r_1_4_3, casebook, []]
            >>> assert dump_content_tree(casebook)[1][0] == s_1
            >>> assert dump_content_tree(casebook)[2][0] == s_2
            >>> s_1_4.refresh_from_db()
            >>> assert dump_content_tree(s_1_4)[0][0] == r_1_4_2
        """
        # check rules
        if new_ordinals == self.ordinals:
            return
        if len(new_ordinals) < 1:
            raise ValueError("Cannot move node to root")
        if self.is_legacy_casebook_node:
            raise ValueError("Cannot move legacy casebook node")
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
            raise ValueError(f"Invalid new ordinals; parent does not exist: {new_ordinals}")
        if new_parent.is_resource:
            raise ValueError('Cannot add descendant of Resource')

        # remove node from existing location
        # (look up the location, instead of using self, so we have the copy where content_tree is populated)
        moved_node = common_parent_node.content_tree__get_descendant(old_ordinals)
        if moved_node != self:
            raise ValueError(f"Unexpected element found at ordinal {old_ordinals}: {moved_node}")
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

            >>> casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2 = getfixture('full_casebook_parts')
            >>> r_1_1.does_display_ordinals = False
            >>> r_1_1.save()
            >>> casebook.content_tree__repair()
            >>> calculated_ordinals = [x.ordinals for x in casebook.contents.all()]
            >>> assert calculated_ordinals == [[1], [1, 1], [1, 2], [1, 3], [1, 4], [1, 4, 1], [1, 4, 2], [1, 4, 3], [2]]
            >>> calculated_strings = [x.ordinal_string() for x in casebook.contents.all()]
            >>> assert calculated_strings == ['1', '', '1.1', '1.2', '1.3', '1.3.1', '1.3.2', '1.3.3', '2']
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
        for node in [self] + list(self.contents.all()):
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
        bulk_update_with_history(to_update, ContentNode, ['ordinals', 'display_ordinals'], batch_size=500, default_change_reason="Tree Repair")

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
            correct_ordinals = self.ordinals + [i + 1]
            if node.does_display_ordinals:
                current_display_ordinal += 1
            current_display_ordinals = self.display_ordinals + [current_display_ordinal]
            if node.ordinals != correct_ordinals or not (node.display_ordinals) or node.display_ordinals != current_display_ordinals:
                node.ordinals = correct_ordinals
                node.display_ordinals = self.display_ordinals + [current_display_ordinal]
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
        return self.ordinals[:len(parent.ordinals)] == parent.ordinals

    def content_tree__get_same_tree_node_from_ordinals(self, ordinals):
        """
            Fetch a node from the database with the given ordinals that is part of the same tree as self,
            or the root of the tree, the node's Casebook.
        """
        return ContentNode.objects.get(ordinals=ordinals,
                                       casebook_id=self.casebook_id) if ordinals else Casebook.objects.get(id=self.casebook_id)

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
        A human-friendly rendering of the "display_ordinals" field.
        """
        return '.'.join(str(o) for o in self.display_ordinals) if self.does_display_ordinals else ''

    def ordinal_coordinate(self):
        return '.'.join(str(o) for o in self.ordinals)

    def ordinals_with_urls(self, editing=False):
        """
        A helper method for assembling ContentNodes' breadcrumb links.
        """
        return [{'ordinal':display_ordinal,
                'ordinals':self.display_ordinals[:index+1],
                'url': ContentNode.objects.get(
                    casebook_id=self.casebook_id,
                    ordinals=self.ordinals[:index+1]
                ).get_edit_or_absolute_url(editing)}
                for index, display_ordinal in enumerate(self.display_ordinals)]


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
        return type(self).objects.filter(id=self.provenance[0]).get().casebook

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



#
# End ContentNode Proxies
#

class CommonTitle(BigPkModel):
    """
    Commonly referred to as 'series', a many-to-many relationship among casebooks
    where a single casebook is designated as the current edition
    """
    name = models.CharField(max_length=300, blank=False, null=False)
    public_url = models.CharField(max_length=300, blank=False, null=False, validators=[validate_unicode_slug])
    current = models.ForeignKey('Casebook', on_delete=models.DO_NOTHING, blank=False, null=False, related_name='title_name')

    class Meta:
        managed = True

    def public_casebooks(self):
        return Casebook.objects.filter(common_title=self).exclude(state=Casebook.LifeCycle.ARCHIVED.value).exclude(state=Casebook.LifeCycle.DRAFT.value).exclude(state=Casebook.LifeCycle.PREVIOUS_SAVE.value)

class Link(NullableTimestampedModel):
    name = models.CharField(max_length=1024, blank=True, null=True)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    url = models.URLField(max_length=1024)
    public = models.BooleanField(null=True, default=True)
    content_type = models.CharField(max_length=255, blank=True, null=True)
    history = HistoricalRecords()

    def get_name(self):
        return self.name if self.name else f"Link to {urlparse(self.url).netloc}"

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
    doc_class = models.CharField(max_length=40, blank=True, null=True)
    created_via_import = models.BooleanField(default=False)
    history = HistoricalRecords()

    class Meta:
        indexes = [
            models.Index(fields=['created_at']),
            models.Index(fields=['name']),
            models.Index(fields=['updated_at']),
        ]

    def get_name(self):
        """For consistency, expose name via this method, which is exposed by Link"""
        return self.name

    def identify_type(self):
        if not self.content:
            return 'Text'
        pq = PyQuery(self.content)
        if pq('embed') or pq('iframe') or pq('img'):
            return 'Multimedia'
        return 'Text'

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
            >>> caplog.clear()
            >>> with caplog.at_level(logging.DEBUG):
            ...     textblock.resource.save()
            >>> assert dump_annotated_text(textblock) == new_textblock_html_with_annotations
            >>> assert caplog.record_tuples[0][2] == 'Normalizing newlines in TextBlock content'
            >>> assert caplog.record_tuples[1][2] == 'Sanitizing TextBlock content'
            >>> assert caplog.record_tuples[2][2] == 'Stripping trailing whitespace in TextBlock content'
            >>> assert caplog.record_tuples[3][2] == 'Updating annotations for TextBlock'
        """
        cleanse_html_field(self, 'content', True)
        self.doc_class = self.identify_type()
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
        raise ValidationError(f'{value} is already in use')



class SavedImage(TimestampedModel):
    name = models.CharField(max_length=255, null=True, blank=True)
    external_id = models.UUIDField(unique=True)
    image = models.FileField(storage=image_storage)
    uploaded_by = models.ForeignKey('User', on_delete='DO_NOTHING', related_name='saved_images')

    class Meta:
        indexes = [models.Index(fields=['external_id'])]

    @property
    def url(self):
        return reverse('image_url', args=[self.external_id])



class EmailWhitelist(models.Model):
    university_name = models.CharField(max_length=255, blank=True, null=True)
    university_url = models.URLField(max_length=1024)
    email_domain = models.CharField(max_length=255, blank=True, null=True)

class LiveSettings(models.Model):
    prevent_exports = models.BooleanField(blank=False, default=False, null=False)
    export_average_rate = models.IntegerField(blank=False, default=0)
    export_last_minute_updated = models.IntegerField(blank=False, default=0)

    @classmethod
    @transaction.atomic
    def export_is_rate_limited(cls):
        """
        >>> ls, full_casebook, resource = [getfixture(f) for f in ['live_settings','full_casebook','resource']]
        >>> prior_count = ls.export_average_rate
        >>> _ = full_casebook.export(False)
        >>> _ = resource.export(False)
        >>> ls.refresh_from_db()
        >>> assert ls.export_average_rate == prior_count + 2
        """
        live_settings = LiveSettings.load()
        current_time = datetime.now()
        minute = current_time.hour*60 + current_time.minute
        elapsed_minutes = (minute-live_settings.export_last_minute_updated) % 1440
        new_rate = max(live_settings.export_average_rate - (elapsed_minutes * settings.EXPORT_RATE_FALLOFF), 0)
        if new_rate > settings.MAX_EXPORTS_PER_HOUR:
            return True
        live_settings.export_average_rate = new_rate + 1
        live_settings.export_last_minute_updated = minute
        live_settings.save()
        return False

    def save(self, *args, **kwargs):
        LiveSettings.objects.exclude(id=self.id).delete()
        super().save(*args, **kwargs)

    @classmethod
    def load(cls):
        try:
            return LiveSettings.objects.get()
        except LiveSettings.DoesNotExist:
            return LiveSettings()

    class Meta:
        verbose_name_plural = "Live settings"


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

