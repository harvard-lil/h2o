from typing import (
    Sequence,
)  # noqa: F401 workaround for django-stubs#1022 until the fix in django-stubs#1028 is released
from typing import Type, Union
from dateutil import parser
import time
import logging
from pathlib import Path
import re
import requests
from datetime import datetime
from enum import Enum
from os.path import commonprefix
from test.test_helpers import (
    dump_annotated_text,
    dump_casebook_outline,
    dump_content_tree,
    dump_content_tree_children,
)
from urllib.parse import urlparse

import lxml.etree
import lxml.sax
from lxml import html
from django.conf import settings
from django.contrib.auth import user_logged_in
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.contrib.postgres.fields import ArrayField
from django.contrib.postgres.indexes import GinIndex
from django.contrib.postgres.search import (
    SearchVector,
    SearchVectorField,
    SearchQuery,
    SearchRank,
    SearchHeadline,
)
from django.core.exceptions import ValidationError
from django.core.validators import validate_unicode_slug, MaxLengthValidator
from django.db import models, connection, transaction, ProgrammingError
from django.core.paginator import Paginator
from django.db.models import Count, F, JSONField
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
from .utils import (
    block_level_elements,
    clone_model_instance,
    elements_equal,
    get_ip_address,
    looks_like_case_law_link,
    looks_like_citation,
    normalize_newlines,
    parse_html_fragment,
    remove_empty_tags,
    strip_trailing_block_level_whitespace,
    void_elements,
    rich_text_export,
    prefix_ids_hrefs,
    APICommunicationError,
    fix_after_rails,
    export_via_aws_lambda,
)
from .storages import get_s3_storage

logger = logging.getLogger(__name__)

#
# Helpers
#

image_storage = get_s3_storage(bucket_name="h2o.images")


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
        self.original_state = {
            k: getattr(self, k) for k in self.tracked_fields if k in self.__dict__
        }

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

    run_if_field_changed(
        normalize_newlines, f"Normalizing newlines in {type(model_instance).__name__} {fieldname}"
    )
    if sanitize_field:
        run_if_field_changed(sanitize, f"Sanitizing {type(model_instance).__name__} {fieldname}")
    run_if_field_changed(
        strip_trailing_block_level_whitespace,
        f"Stripping trailing whitespace in {type(model_instance).__name__} {fieldname}",
    )


class AnnotatedModel(EditTrackedModel):
    """
    Abstract base class for LegalDocument and TextBlock resource types, which can be annotated. Ensures that annotation
    offsets will be updated when the text contents of this resource are modified.
    """

    class Meta:
        abstract = True

    tracked_fields = ["content"]

    def related_annotations(self):
        return ContentAnnotation.objects.valid().filter(
            resource__resource_id=self.id, resource__resource_type=self.__class__.__name__
        )

    def save(self, *args, **kwargs):
        if self.pk and self.has_changed("content"):
            logger.debug(f"Updating annotations for {type(self).__name__}")
            ContentAnnotation.update_annotations(
                self.related_annotations(), self.original_state["content"], self.content
            )
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
        return case_name[: max_part_length * 2 + 4] + (
            "..." if len(case_name) > (max_part_length * 2 + 4) else ""
        )
    part_a = parts[0][:max_part_length] + ("..." if len(parts[0]) > max_part_length else "")
    part_b = parts[1][:max_part_length] + ("..." if len(parts[1]) > max_part_length else "")
    return part_a + " v. " + part_b


class CAP:

    details = {
        "name": "CAP",
        "short_description": "CAP provides US Case law up to 2018",
        "long_description": "The Caselaw Access Project contains three hundred and sixty years of United States caselaw",
        "link": "https://case.law/",
        "search_regexes": [
            {"name": "US Case Law", "regex": r"\b[0-9]+ (?:[0-9A-Z][0-9a-z.]*[ .])+[0-9]+\b"},
            {"name": "US Case Law", "regex": "https://cite.case.law/.*"},
            {"name": "US Case Law", "regex": r"( vs?[.]? )|(\bin re:\b)|(ex parte)", "fuzzy": True},
        ],
        "footnote_regexes": [
            # these are identical, except they order the html attributes differently
            r'<a id="ref_footnote_[\d]+_[\d]+" class="footnotemark" href="#footnote_[\d]+_[\d]+">.*<aside',
            r'<a class="footnotemark" href="#footnote_[\d]+_[\d]+" id="ref_footnote_[\d]+_[\d]+">.*<aside',
        ],
    }

    @staticmethod
    def convert_search_result(result):
        cites = [x["cite"] for x in result["citations"] if x["type"] == "official"] + [
            x["cite"] for x in result["citations"] if x["type"] != "official"
        ]
        return {
            "fullName": result.get("name", result.get("name_abbreviation", "")),
            "shortName": truncate_name(result.get("name_abbreviation", result.get("name", ""))),
            "fullCitations": ", ".join(cites),
            "shortCitations": ", ".join(cites[:3]) + ("..." if len(cites) > 3 else ""),
            "effectiveDate": result.get("decision_date", None),
            "url": result.get("frontend_url", None),
            "id": result.get("id", None),
        }

    @staticmethod
    def looks_like_url(query):
        return looks_like_case_law_link(query)

    @staticmethod
    def convert_frontend_url(url):
        frontend_url = url.split("cite.case.law")[1]
        frontend_split = frontend_url[1:-1].split("/")
        # https://github.com/harvard-lil/capstone/blob/fe072badff59c4127d2ce82a557b287aaefc79f0/capstone/cite/urls.py#L14
        if len(frontend_split) == 4:
            id = frontend_split[-1]
            return {"id": id}
        elif len(frontend_split) == 3:
            reporter, volume, page = frontend_split
            citation = f"{volume} {reporter.replace('-', ' ')} {page}"
            return {"cite": citation}
        return {"frontend_url": frontend_url}

    @staticmethod
    def cap_params(search_params):
        if search_params.q:
            query = search_params.q.replace("’", "'")
            if looks_like_case_law_link(query):
                return CAP.convert_frontend_url(query)
            elif looks_like_citation(query):
                return {"cite": query}

        params = {
            "name_abbreviation": search_params.name if search_params.name else search_params.q,
            "cite": search_params.citation,
            "decision_date_max": search_params.before_date,
            "decision_date_min": search_params.after_date,
            "jurisdiction": search_params.jurisdiction,
        }
        return {k: params[k] for k in params.keys() if params[k] is not None}

    @staticmethod
    def search(search_params):
        param_defaults = {"page_size": 30, "ordering": "-analysis.pagerank.percentile"}
        # In some cases, cap search will return too many results for what should be a unique search by frontend_urls
        supplied_cap_params = CAP.cap_params(search_params)
        cap_params = {**param_defaults, **supplied_cap_params}
        response = requests.get(settings.CAPAPI_BASE_URL + "cases/", cap_params)
        try:
            results = response.json()["results"]
        except Exception:
            results = []
        return [CAP.convert_search_result(x) for x in results]

    @staticmethod
    def preprocess_body(body):
        return body

    @staticmethod
    def postprocess_content(body, postfix_id, export_options=None):
        def style_page_no(_, pn):
            pn.attrib["data-custom-style"] = "Page Number"
            pn.addprevious(lxml.etree.XML("<span> </span>"))
            pn.addnext(lxml.etree.XML("<span> </span>"))

        def unlink_page_nos(_, page_no):
            page_no.tag = "span"
            page_no.attrib["data-custom-style"] = "Page Number"

        body_parsed = PyQuery(body)
        # Footnotes
        for aside in (
            body_parsed("aside.footnote")
            .filter(lambda _, this: len(PyQuery(this).children()) > 1)
            .items()
        ):
            link, first_p = [PyQuery(x) for x in aside.children()[:2]]
            first_p.html(link.outer_html() + first_p.html())
            link.remove()
            footnote_text_style = "Case Footnote Text" + (
                f"-{postfix_id}"
                if export_options and export_options.get("docx_footnotes", False)
                else ""
            )
            aside.wrap(f'<div data-custom-style="{footnote_text_style}"></div>')

        for mark in body_parsed(".footnotemark").items():
            # Can't just use wrap here, because it grabs some of the surrounding text
            # This also inverts the tags, so the span appears inside the a tag
            # ¯\_(ツ)_/¯

            footnote_style = "Case Footnote Reference" + (
                f"-{postfix_id}"
                if export_options and export_options.get("docx_footnotes", False)
                else ""
            )
            mark.html(f'<span data-custom-style="{footnote_style}">{mark.html()}</span>')

        # Page nos
        body_parsed(".page-label").remove()

        # vanillify citation links
        for link in body_parsed("a.citation"):
            link.tag = "span"

        # Case Header styling
        # for pq in body_parsed('section.head-matter p, center, p[style="text-align:center"], p[align="center"]').items():
        #     pq.wrap("<div data-custom-style='Case Header'></div>")
        for el in body_parsed(
            'section.head-matter h4, center h2, h2[style="text-align:center"], h2[align="center"]'
        ):
            el.tag = "div"
            el.attrib["data-custom-style"] = "Case Header"
        # From cases.scss

        hidden_classes = [
            ".parties",
            ".decisiondate",
            ".docketnumber",
            ".citations",
            ".syllabus",
            ".synopsis",
            ".court",
        ]
        for hide_class in hidden_classes:
            body_parsed.remove(hide_class)

        body_parsed("em [data-custom-style]").add_class("popup_raiser")

        pop_target = '<span data-custom-style="Elision" class="popup_raiser">[ … ]</span>'
        dumped_html = body_parsed.html().replace(pop_target, f"</em>{pop_target}<em>")
        return f'<div data-custom-style="Case Body">{dumped_html}</div>'

    @staticmethod
    def pull(legal_doc_source, id):
        if not settings.CAPAPI_API_KEY:
            raise APICommunicationError("To interact with CAP, CAPAPI_API_KEY must be set.")
        try:
            response = requests.get(
                settings.CAPAPI_BASE_URL + f"cases/{id}/",
                {"full_case": "true", "body_format": "html"},
                headers={"Authorization": f"Token {settings.CAPAPI_API_KEY}"},
            )
            assert response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with CAPAPI failed: {str(e)}"
            raise APICommunicationError(msg)

        metadata = response.json()
        body = CAP.preprocess_body(metadata.pop("casebody", {}).pop("data", None))
        citations = [x.get("cite") for x in metadata.get("citations", []) if "cite" in x]

        # annotate metadata with details about the case's HTML, for convenience
        metadata["html_info"] = {"source": "cap"}
        for regex in CAP.details["footnote_regexes"]:
            if re.search(regex, body, re.DOTALL):
                metadata["html_info"]["footnotes"] = {
                    "style": "cap",
                    "regex": regex,
                    "last_checked_timestamp": datetime.now().timestamp(),
                }
                break
        case = LegalDocument(
            source=legal_doc_source,
            short_name=metadata.get("name_abbreviation"),
            name=metadata.get("name"),
            doc_class="Case",
            citations=citations,
            jurisdiction=metadata.get("jurisdiction", {}).get("slug", ""),
            effective_date=parser.parse(metadata.get("decision_date")),
            publication_date=parser.parse(metadata.get("last_updated")),
            updated_date=datetime.now(),
            source_ref=str(id),
            content=body,
            metadata=metadata,
        )
        return case

    @staticmethod
    def get_metadata(id):
        try:
            response = requests.get(settings.CAPAPI_BASE_URL + f"cases/{id}/", {})
            assert response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with CAPAPI failed: {str(e)}"
            raise APICommunicationError(msg)

        metadata = response.json()
        citations = [x.get("cite") for x in metadata["citations"] if "cite" in x]
        data = {
            "short_name": metadata.get("name_abbreviation"),
            "name": metadata.get("name"),
            "doc_class": "Case",
            "citations": citations,
            "jurisdiction": metadata.get("jurisdiction", {}).get("slug", ""),
            "effective_date": parser.parse(metadata.get("decision_date")),
            "publication_date": parser.parse(metadata.get("last_updated")),
            "updated_date": datetime.now(),
            "source_ref": str(id),
            "metadata": metadata,
        }
        return data

    @staticmethod
    def header_template(legal_document):
        return "cap_header.html"


class USCodeGPO:
    details = {
        "name": "GPO",
        "short_description": "The GPO provides the USCode",
        "long_description": "The GPO provides section level access to the US Code",
        "link": "https://www.govinfo.gov/app/collection/uscode",
        "search_regexes": [
            {"name": "US Code", "regex": "[0-9]* U[.]?S[.]?C[.]? §§? ?[0-9]*(-[0-9]*)?"},
            {"name": "US Code", "regex": "https://www.law.cornell.edu/uscode/.*"},
        ],
        "footnote_regexes": [],
    }

    @staticmethod
    def convert_search_result(result):
        # convert search results to the format the FE expects
        return {
            "fullName": result.title,
            "shortName": truncate_name(result.title),
            "fullCitations": result.citation,
            "shortCitations": result.citation,
            "effectiveDate": result.effective_date,
            "url": result.gpo_url,
            "id": result.gpo_id,
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
        abbreviator = re.compile(r"\bUSC\b", re.IGNORECASE)
        silcrow_spacer = re.compile(r"§([0-9])")
        query = None
        if search_params.q:
            search_params.q = re.sub(abbreviator, "U.S.C.", search_params.q)
            search_params.q = silcrow_spacer.sub(r"§ \1", search_params.q)
        cite_matcher = re.compile("[0-9]+ U.S.C. § ?[0-9]+(-[0-9]+)?")
        if cite_matcher.match(search_params.q):
            search_params.citation = search_params.q
            query = SearchQuery(search_params.citation)
            search_params.q = None
        search_fields = {}
        if search_params.before_date:
            search_fields["effective_date__lte"] = search_params.before_date
        if search_params.after_date:
            search_fields["effective_date__gte"] = search_params.after_date
        if search_params.citation:
            search_fields["citation"] = search_params.citation
        if search_params.frontend_url:
            search_fields["lii_url"] = search_params.frontend_url
        if search_params.q:
            if USCodeGPO.looks_like_url(search_params.q):
                search_fields["lii_url"] = search_params.q
            query = SearchQuery(search_params.q, config="english")
            search_fields["search_field"] = query

        vector = SearchVector("citation", config="english", weight="A") + SearchVector(
            "title", config="english", weight="B"
        )
        return [
            USCodeGPO.convert_search_result(x)
            for x in USCodeIndex.objects.filter(**search_fields)
            .annotate(rank=SearchRank(vector, query))
            .order_by("repealed", "-rank")[:30]
        ]

    @staticmethod
    def parse_gpo_html(full_body):
        any_field = re.compile("<!-- *field-(?P<field>(?:start|end):[^ ]+) *-->")
        br = re.compile("<br */>")
        comment = re.compile("<!-- .* -->")

        def get_field(field_name, text, start_loc=0):
            start = re.compile(f"<!-- *field-start:{field_name} *-->")
            end = re.compile(f"<!-- *field-end:{field_name} *-->")
            start_match = start.search(text, start_loc)
            if not start_match:
                return {"start": None, "end": None, "content": None}
            end_matches = [x.span()[1] for x in end.finditer(text, start_match.span()[1])]
            if not end_matches:
                return {"start": None, "end": None, "content": None}
            field_range = (start_match.span()[0], end_matches[-1])
            return {
                "start": field_range[0],
                "end": field_range[1],
                "content": text[field_range[0] : field_range[1]],
            }

        def strip_brs(text):
            return br.sub("", text)

        def span_contents(text):
            return [x.text for x in PyQuery(text)("span") if x.text]

        def strip_comments(text):
            return comment.sub("", text)

        def parse(text):
            full_body = PyQuery(text)("body").html()
            q = any_field.search(full_body)
            header_section = full_body[: q.span()[0]]
            header_lines = span_contents(header_section)
            statute_body = get_field("statute", full_body)
            notes_start = statute_body["end"] or 0
            notes = get_field("notes", full_body, notes_start)
            return {
                "header": header_lines,
                "body": strip_comments(strip_brs(statute_body["content"]))
                if statute_body["content"]
                else "",
                "notes": strip_comments(strip_brs(notes["content"])) if notes["content"] else "",
            }

        parts = parse(full_body)
        parts["combined_body"] = (
            (parts["body"] or "") + ('\n<h4 class="notes-section">Notes</h4>\n' + parts["notes"])
            if parts["notes"]
            else ""
        )
        return parts

    @staticmethod
    def pull(legal_doc_source, id):
        # given a source_ref/API id return an (unsaved) LegalDocument
        if not settings.GPO_API_KEY:
            raise APICommunicationError("To interact with the GPO API, a key must be set.")
        try:
            package_id = "-".join(id.split("-")[:3])
            body_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/htm",
                {},
                headers={"X-Api-Key": settings.GPO_API_KEY},
            )
            assert body_response.ok
            metadata_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/summary",
                {},
                headers={"X-Api-Key": settings.GPO_API_KEY},
            )
            assert metadata_response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with GPO API failed: {str(e)}"
            raise APICommunicationError(msg)
        metadata = metadata_response.json()

        content = PyQuery(body_response.content)

        effective_date = parser.parse(metadata["dateIssued"])
        publication_date = parser.parse(metadata["lastModified"])
        title_no = id.split("-")[2][5:]
        first_section = metadata["leafRange"]["from"]
        last_section = metadata["leafRange"]["to"]
        single_leaf = first_section == last_section
        silcrow = "§" if single_leaf else "§§"
        sections = first_section if single_leaf else first_section + "-" + last_section
        citation = f"{title_no} U.S.C. {silcrow} {sections}"

        parsed_body = USCodeGPO.parse_gpo_html(content)
        metadata["header"] = parsed_body["header"]
        formatted_body = parsed_body["combined_body"]
        code = LegalDocument(
            source=legal_doc_source,
            name=metadata["title"],
            doc_class="Code",
            citations=[citation],
            effective_date=effective_date,
            publication_date=publication_date,
            updated_date=datetime.now(),
            source_ref=id,
            content=formatted_body,
            metadata=metadata,
        )
        return code

    @staticmethod
    def get_metadata(id):
        # given a source_ref/API id return an (unsaved) LegalDocument
        if not settings.GPO_API_KEY:
            raise APICommunicationError("To interact with the GPO API, a key must be set.")
        try:
            package_id = "-".join(id.split("-")[:3])
            body_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/htm",
                {},
                headers={"X-Api-Key": settings.GPO_API_KEY},
            )
            assert body_response.ok
            metadata_response = requests.get(
                f"{settings.GPO_BASE_URL}packages/{package_id}/granules/{id}/summary",
                {},
                headers={"X-Api-Key": settings.GPO_API_KEY},
            )
            assert metadata_response.ok
        except (requests.RequestException, AssertionError) as e:
            msg = f"Communication with GPO API failed: {str(e)}"
            raise APICommunicationError(msg)
        metadata = metadata_response.json()

        content = PyQuery(body_response.content)

        effective_date = parser.parse(metadata["dateIssued"])
        publication_date = parser.parse(metadata["lastModified"])
        title_no = id.split("-")[2][5:]
        first_section = metadata["leafRange"]["from"]
        last_section = metadata["leafRange"]["to"]
        single_leaf = first_section == last_section
        silcrow = "§" if single_leaf else "§§"
        sections = first_section if single_leaf else first_section + "-" + last_section
        citation = f"{title_no} U.S.C. {silcrow} {sections}"

        parsed_body = USCodeGPO.parse_gpo_html(content)
        metadata["header"] = parsed_body["header"]
        code = {
            "name": metadata["title"],
            "doc_class": "Code",
            "citations": [citation],
            "effective_date": effective_date,
            "publication_date": publication_date,
            "updated_date": datetime.now(),
            "source_ref": id,
            "metadata": metadata,
        }
        return code

    @staticmethod
    def header_template(legal_document):
        return "gpo_header.html"


class LegacyNoSearch:
    details = {
        "name": "LegacyDocument",
        "short_description": "ERROR",
        "long_description": "ERROR",
        "link": "ERROR",
        "search_regexes": [],
        "footnote_regexes": [],
    }

    @staticmethod
    def search(search_params):
        return []

    @staticmethod
    def pull(legal_doc_source, id):
        return None

    @staticmethod
    def header_template(legal_document):
        return "empty_header.html"


def get_display_name_field(category):
    display_name_fields = {
        "legal_doc": "display_name",
        "legal_doc_fulltext": "display_name",
        "link": "name",
        "textblock": "name",
        "casebook": "title",
        "user": "attribution",
    }
    return f"metadata__{display_name_fields[category]}"


def dump_search_results(parts):
    return (
        [
            {k: "..." if k == "created_at" else v for k, v in r.metadata.items()}
            for r in parts[0].object_list
        ],
    ) + tuple(parts[1:])


class SearchIndex(models.Model):
    result_id = models.IntegerField()
    document = SearchVectorField()
    metadata = JSONField()
    category = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = "internal_search_view"

    @classmethod
    def create_search_index(cls):
        """Create or replace the materialized view 'search_view', which backs this model"""
        with connection.cursor() as cursor:
            cursor.execute(Path(__file__).parent.joinpath("create_search_index.sql").read_text())

    @classmethod
    def refresh_search_index(cls):
        """Refresh the contents of the materialized view"""
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
    def _search(
        cls,
        category,
        query=None,
        page_size=10,
        page=1,
        filters={},
        facet_fields=[],
        order_by=None,
        base_query=None,
    ):
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
        ...         {'affiliation': 'Affiliation 0', 'created_at': '...', 'title': 'Some Title 0', 'attribution': 'Some User 0', 'description': None},
        ...         {'affiliation': 'Affiliation 1', 'created_at': '...', 'title': 'Some Title 1', 'attribution': 'Some User 1', 'description': None},
        ...         {'affiliation': 'Affiliation 2', 'created_at': '...', 'title': 'Some Title 2', 'attribution': 'Some User 2', 'description': None}
        ...     ],
        ...     {'user': 3, 'legal_doc': 3, 'casebook': 3},
        ...     {}
        ... )

        Get casebooks by query string:
        >>> assert len(dump_search_results(SearchIndex().search('casebook', 'Some Title 0'))[0]) == 1

        Get casebooks by filter field:
        >>> assert len(dump_search_results(SearchIndex().search('casebook', filters={'attribution': 'Some User 1'}))[0]) == 1

        Get all users:
        >>> assert len(dump_search_results(SearchIndex().search('user'))[0]) == 3

        Get all cases:
        >>> assert len(dump_search_results(SearchIndex().search('legal_doc'))[0]) == 3
        """
        if base_query is None:
            base_query = cls.objects.all()
        query_vector = SearchQuery(query, config="english") if query else None
        if query_vector:
            base_query = base_query.filter(document=query_vector)
        for k, v in filters.items():
            base_query = base_query.filter(**{f"metadata__{k}": v})

        # get results
        results = base_query.filter(category=category).only("result_id", "metadata")
        if query_vector:
            results = results.annotate(rank=SearchRank(F("document"), query_vector))

        display_name = get_display_name_field(category)
        order_by_expression = [display_name]
        if order_by:
            # Treat 'decision date' like 'created at', so that sort-by-date is maintained
            # when switching between case and casebook tab.
            fix_after_rails('consider renaming these params "date".')
            if query and order_by == "score":
                order_by_expression = ["-rank", display_name]
            elif category == "casebook":
                if order_by in ["created_at", "effective_date"]:
                    order_by_expression = ["-metadata__created_at", display_name]
            elif category == "case":
                if order_by in ["created_at", "effective_date"]:
                    order_by_expression = ["-metadata__effective_date", display_name]

        results = results.order_by(*order_by_expression)
        results = Paginator(results, page_size).get_page(page)

        # get counts
        counts = {
            c["category"]: c["total"]
            for c in base_query.values("category").annotate(total=Count("category"))
        }
        results.__dict__["count"] = counts.get(
            category, 0
        )  # hack to avoid redundant query for count

        # get facets
        facets = {}
        for facet in facet_fields:
            facet_param = f"metadata__{facet}"
            facets[facet] = (
                base_query.filter(category=category)
                .exclude(**{facet_param: ""})
                .order_by(facet_param)
                .values_list(facet_param, flat=True)
                .distinct()
            )

        return results, counts, facets


class FullTextSearchIndex(models.Model):
    result_id = models.IntegerField()
    document = SearchVectorField()
    metadata = JSONField()
    category = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = "fts_internal_search_view"

    @classmethod
    def create_search_index(cls):
        """Create or replace the materialized view 'search_view', which backs this model"""
        with connection.cursor() as cursor:
            cursor.execute(Path(__file__).parent.joinpath("create_fts_index.sql").read_text())

    @classmethod
    def refresh_search_index(cls):
        """Refresh the contents of the materialized view"""
        with connection.cursor() as cursor:
            try:
                cursor.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY fts_internal_search_view")
            except ProgrammingError as e:
                if e.args[0].startswith('relation "fts_internal_search_view" does not exist'):
                    cls.create_search_index()

    @classmethod
    def search(cls, *args, **kwargs):
        for i in range(3):
            try:
                return cls.casebook_fts(*args, **kwargs)
            except ProgrammingError as e:
                if e.args[0].startswith('relation "fts_internal_search_view" does not exist'):
                    pass
            time.sleep(0.01)
        raise ProgrammingError("Internal full-text search view has not been created correctly!")

    @classmethod
    def casebook_fts(
        cls,
        casebook_id: int,
        category: str,
        query_str: str,
        page_size=10,
        page=1,
        *args,
        **kwargs,
    ):
        """
        Given a casebook ID and search parameters, run a full-text search on
        all text within the casebook. Currently, this only searches through legal
        documents. However, this will be expanded to include all casebook text.

        Given:
        >>> _, legal_document_factory, casebook_factory, content_node_factory, text_block_factory = [getfixture(i) for i in ['reset_sequences', 'legal_document_factory', 'casebook_factory', 'content_node_factory', 'text_block_factory']]
        >>> casebooks = [casebook_factory() for i in range(3)]
        >>> nodes = [content_node_factory() for i in range(6)]
        >>> docs = [legal_document_factory() for i in range(3)]
        >>> text = [text_block_factory() for i in range(3)]
        >>> for d, n in zip(docs, nodes[:3]):
        ...     n.resource_type = 'LegalDocument'
        ...     n.resource_id = d.id
        ...     n.casebook_id = casebooks[0].id
        ...     n.save()
        >>> for t, n in zip(text, nodes[3:]):
        ...     n.resource_type = 'TextBlock'
        ...     n.resource_id = t.id
        ...     n.casebook_id = casebooks[0].id
        ...     n.save()
        >>> FullTextSearchIndex().create_search_index()

        Search in casebook by query:
        >>> assert dump_search_results([FullTextSearchIndex().casebook_fts(casebooks[0].id, 'legal_doc_fulltext', query_str='2'),]) == (
        ...     [
        ...         {'citations': ['Adventures in criminality, 1 Fake 1, (2001)',], 'display_name': 'Legal Doc 2', 'jurisdiction': None, 'effective_date': '1900-01-01T00:00:00+00:00', 'effective_date_formatted': 'January   1, 1900', 'headlines': ['Dubious legal claim <b>2</b>'], 'ordinals': '', 'year': '1900'}
        ...     ],
        ... )
        >>> assert len(dump_search_results([FullTextSearchIndex().casebook_fts(casebooks[0].id, "legal_doc_fulltext", query_str='Dubious'),])[0]) == 3
        >>> assert len(dump_search_results([FullTextSearchIndex().casebook_fts(casebooks[0].id, 'textblock', query_str='2'),])[0]) == 1
        """

        casebook = Casebook.objects.get(id=casebook_id)

        base_query = None
        if category == "legal_doc_fulltext":
            legal_doc_ids = casebook.contents.filter(resource_type="LegalDocument").values_list(
                "resource_id", flat=True
            )
            base_query = FullTextSearchIndex.objects.filter(category="legal_doc_fulltext").filter(
                result_id__in=legal_doc_ids
            )
        elif category == "textblock":
            textblock_ids = casebook.contents.filter(resource_type="TextBlock").values_list(
                "resource_id", flat=True
            )
            base_query = FullTextSearchIndex.objects.filter(category=category).filter(
                result_id__in=textblock_ids
            )
        else:
            textblock_ids = casebook.contents.filter(resource_type="Link").values_list(
                "resource_id", flat=True
            )
            base_query = FullTextSearchIndex.objects.filter(category=category).filter(
                result_id__in=textblock_ids
            )

        query_vector: Union[SearchQuery, str]
        if query_str:
            query_vector = SearchQuery(query_str, config="english")
        else:
            query_vector = ""

        if query_vector:
            base_query = base_query.filter(document=query_vector)

        results = base_query.filter(category=category)
        results = results.annotate(rank=SearchRank(F("document"), query_vector))
        display_name = get_display_name_field(category)
        results = results.order_by("-rank", display_name)

        results_page = Paginator(results, page_size).get_page(page)
        ids = sorted([r.result_id for r in results_page])

        # Can replace w/ match statement when upgraded to 3.10
        query_class: ResourceType
        if category == "legal_doc_fulltext":
            query_class = LegalDocument
        elif category == "textblock":
            query_class = TextBlock
        elif category == "link":
            query_class = Link

        content_name = "description" if category == "link" else "content"
        ids_headlines_query = (
            query_class.objects.filter(id__in=ids)
            .annotate(
                headlines=SearchHeadline(
                    content_name, query_str, max_fragments=20, min_words=10, max_words=20
                )
            )
            .values_list("id", "headlines")
        )

        ids_headlines = {i: h for i, h in ids_headlines_query}
        ids_ordinals: dict[int, list[str]]

        if category == "legal_doc_fulltext":
            ids_ordinals_nodes = (
                casebook.contents.filter(resource_type="LegalDocument")
                .filter(resource_id__in=[r.result_id for r in results_page])
                .values_list("resource_id", "ordinals")
            )
            ids_ordinals = {i: [str(n) for n in h] for i, h in ids_ordinals_nodes}  # type: ignore

        for r in results_page:
            try:
                r.metadata["headlines"] = ids_headlines[r.result_id].split("...")
            except AttributeError:
                pass

            if category == "legal_doc_fulltext":
                r.metadata["ordinals"] = ".".join(ids_ordinals[r.result_id])

                if r.metadata["citations"]:
                    r.metadata["citations"] = r.metadata["citations"].split(";;")
                else:
                    r.metadata["citations"] = ""

                if r.metadata["effective_date_formatted"]:
                    r.metadata["year"] = (
                        r.metadata["effective_date_formatted"].split(",")[-1].strip()
                    )
                else:
                    r.metadata["year"] = ""

        return results_page


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
        self.search_field = SearchVector("citation", weight="A") + SearchVector("title", weight="B")
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
        ordering = ["priority"]

    @classmethod
    def register_api(cls, api):
        if api.details["name"] not in cls.source_apis:
            cls.source_apis[api.details["name"]] = api

    def api_model(self):
        # short_description, long_description, bulk_process, search(long_citation_json), import(id)
        if self.search_class in self.source_apis:
            return self.source_apis[self.search_class]
        raise ValueError(f"Missing API Model for {self.name}")

    def get_metadata(self, id):
        api_model = self.api_model()
        return (hasattr(api_model, "get_metadata") and api_model.get_metadata(id)) or None

    def pull(self, id):
        return self.api_model().pull(self, id)

    def most_recent_with_id(self, id):
        return (
            LegalDocument.objects.filter(source=self, source_ref=id)
            .order_by("-effective_date", "-publication_date")
            .first()
        )


LegalDocumentSource.register_api(USCodeGPO)
LegalDocumentSource.register_api(CAP)
LegalDocumentSource.register_api(LegacyNoSearch)


class LegalDocument(NullableTimestampedModel, AnnotatedModel):
    source = models.ForeignKey(
        "LegalDocumentSource", on_delete=models.DO_NOTHING, related_name="documents"
    )
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
            GinIndex(fields=["citations"]),
        ]

    @property
    def header_template(self):
        base = "includes/legal_doc_sources/"
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
        cleanse_html_field(self, "content")
        super().save(*args, **kwargs)

    @property
    def get_title(self):
        return self.short_name or self.name

    def get_name(self):
        return self.short_name or self.name

    def __str__(self):
        return self.get_name()

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type="LegalDocument")

    @property
    def cite_string(self):
        return ", ".join(self.citations)

    # Utility functions

    def has_newer_version(self):
        if self.source.name == "Legacy":
            return False
        latest_downloaded = self.source.most_recent_with_id(self.source_ref)
        if latest_downloaded.publication_date > self.publication_date:
            return True
        latest_meta = self.source.get_metadata(self.source_ref)
        return latest_meta and latest_meta["publication_date"] > timezone.utc.localize(
            self.publication_date
        )

    def get_latest_version(self, only_local=False):
        latest_version = (
            self.source.most_recent_with_id(self.source_ref)
            if only_local
            else self.source.pull(self.source_ref)
        )
        if latest_version.publication_date <= timezone.utc.localize(self.publication_date):
            return self
        return latest_version

    def has_bad_footnotes(self):
        pq = PyQuery(self.content)
        self_links = [a for a in pq("a") if a.attrib.get("href", "").startswith("#")]
        for sl in self_links:
            target_id = sl.attrib.get("href")[1:]
            if not pq(f'[id="{target_id}"]'):
                return True
        return False


class ContentAnnotationQuerySet(models.QuerySet):
    def valid(self):
        """
        Return annotations excluding those that were marked invalid when shifting.
        """
        return self.exclude(global_start_offset=-1, global_end_offset=-1)


# (2022-07-19) django type-stubs workaround
# https://github.com/typeddjango/django-stubs#my-queryset-methods-are-returning-any-rather-than-my-model
_ContentAnnotationManager = models.Manager.from_queryset(ContentAnnotationQuerySet)


class ContentAnnotation(TimestampedModel, BigPkModel):
    kind = models.CharField(
        max_length=255,
        choices=(
            ("replace", "replace"),
            ("highlight", "highlight"),
            ("elide", "elide"),
            ("note", "note"),
            ("link", "link"),
            ("correction", "correction"),
        ),
    )
    content = models.TextField(blank=True, null=True)
    global_start_offset = models.IntegerField(blank=True, null=True)
    global_end_offset = models.IntegerField(blank=True, null=True)

    resource = models.ForeignKey(
        "ContentNode",
        on_delete=models.CASCADE,
        related_name="annotations",
    )

    objects = _ContentAnnotationManager()

    history = HistoricalRecords()

    class Meta:
        indexes = [
            models.Index(
                fields=[
                    "resource",
                ]
            )
        ]
        # annotations return in document order, with id to ensure sort stability
        ordering = ["global_start_offset", "id"]

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
            if (
                new_start == annotation.global_start_offset
                and new_end == annotation.global_end_offset
            ):
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
            bulk_update_with_history(
                to_update,
                ContentAnnotation,
                ["global_start_offset", "global_end_offset"],
                batch_size=500,
                default_change_reason="Automated Shift",
            )


class CasebookFollow(TimestampedModel, BigPkModel):
    user = models.ForeignKey(
        "User",
        on_delete=models.CASCADE,
    )
    casebook = models.ForeignKey("Casebook", on_delete=models.DO_NOTHING, blank=True, null=True)

    class Meta:
        unique_together = (("user", "casebook"),)


class ContentCollaborator(TimestampedModel, BigPkModel):
    has_attribution = models.BooleanField(default=False)
    can_edit = models.BooleanField(default=False)
    user = models.ForeignKey(
        "User",
        on_delete=models.CASCADE,
    )
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete unneeded ContentCollaborator rows in the Casebook.delete method.
    casebook = models.ForeignKey("Casebook", on_delete=models.DO_NOTHING, blank=True, null=True)

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)

    class Meta:
        unique_together = (("user", "casebook"),)


class ContentNodeQuerySet(models.QuerySet):
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
            for resource_type, query in (
                ("TextBlock", textblock_query),
                ("Link", link_query),
                ("LegalDocument", legal_doc_query),
            ):
                for obj in query.filter(
                    id__in=[
                        obj.resource_id
                        for obj in self._result_cache
                        if obj.resource_type == resource_type
                    ]
                ):
                    resources[(resource_type, obj.id)] = obj
            for content_node in self._result_cache:
                if content_node.resource_id:
                    content_node._resource = resources.get(
                        (content_node.resource_type, content_node.resource_id)
                    )
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
        next_ordinal = prefix + [
            max([x.ordinals[-1] for x in self.content_tree__children] or [0]) + 1
        ]
        next_display_ordinal = prefix + [
            max(
                [x.ordinals[-1] for x in self.content_tree__children if x.does_display_ordinals]
                or [0]
            )
            + 1
        ]
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
        if new_ordinals[: len(self.ordinals)] == self.ordinals:
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
            raise ValueError("Cannot add descendant of Resource")

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
            raise ValueError(
                "Cannot use content_tree.parent before calling content_tree.load on parent node."
            )
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
        bulk_update_with_history(
            to_update,
            ContentNode,
            ["ordinals", "display_ordinals"],
            batch_size=500,
            default_change_reason="Tree Repair",
        )

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
            if (
                node.ordinals != correct_ordinals
                or not (node.display_ordinals)
                or node.display_ordinals != current_display_ordinals
            ):
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
        return self.ordinals[: len(parent.ordinals)] == parent.ordinals

    def content_tree__get_same_tree_node_from_ordinals(self, ordinals):
        """
        Fetch a node from the database with the given ordinals that is part of the same tree as self,
        or the root of the tree, the node's Casebook.
        """
        return (
            ContentNode.objects.get(ordinals=ordinals, casebook_id=self.casebook_id)
            if ordinals
            else Casebook.objects.get(id=self.casebook_id)
        )

    def content_tree__get_descendant(self, ordinals):
        """
        Fetch a node from content_tree__children with the given ordinals.
        """
        if ordinals[: len(self.ordinals)] != self.ordinals:
            raise ValueError("Ordinal value is not a descendant of self")
        node = self
        ordinals = ordinals[len(self.ordinals) :]
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
        return ".".join(str(o) for o in self.display_ordinals) if self.does_display_ordinals else ""

    def ordinal_coordinate(self):
        return ".".join(str(o) for o in self.ordinals)

    def ordinals_with_urls(self, editing=False):
        """
        A helper method for assembling ContentNodes' breadcrumb links.
        """
        return [
            {
                "ordinal": display_ordinal,
                "ordinals": self.display_ordinals[: index + 1],
                "url": ContentNode.objects.get(
                    casebook_id=self.casebook_id, ordinals=self.ordinals[: index + 1]
                ).get_edit_or_absolute_url(editing),
            }
            for index, display_ordinal in enumerate(self.display_ordinals)
        ]


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


# (2022-07-19) django type-stubs workaround
# https://github.com/typeddjango/django-stubs#my-queryset-methods-are-returning-any-rather-than-my-model
_ContentNodeManager = models.Manager.from_queryset(ContentNodeQuerySet)


class ContentNode(
    EditTrackedModel, TimestampedModel, BigPkModel, MaterializedPathTreeMixin, TrackedCloneable
):
    title = models.CharField(max_length=10000, default="Untitled")
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)
    headnote_doc_class = models.CharField(max_length=40, blank=True, null=True)
    copy_of = models.ForeignKey(
        "self",
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name="clones",
    )
    history = HistoricalRecords()

    # Some fields are only used by certain subsets of ContentNodes
    # https://github.com/harvard-lil/h2o/issues/1035

    # legacy casebook nodes only
    public = models.BooleanField(default=False)
    draft_mode_of_published_casebook = models.BooleanField(
        blank=True, null=True, help_text="Unknown (None) or True; never False"
    )

    # sections and resources only
    # This is marked "on_delete=models.DO_NOTHING" to avoid unnecessary queries when deleting Sections and Resources....
    # We make sure to delete Casebook contents in the Casebook.delete method.
    old_casebook = models.ForeignKey(
        "ContentNode",
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name="old_casebook_contents",
    )

    casebook = models.ForeignKey(
        "Casebook", on_delete=models.DO_NOTHING, blank=True, null=True, related_name="contents"
    )

    # This field, together with resource_id, defines a relationship with Link, Textblock, or LegalDocument.
    # May also be blank, 'Section', or 'Temp'.
    # https://github.com/harvard-lil/h2o/issues/1035
    resource_type = models.CharField(max_length=255, blank=True, null=True)
    resource_id = models.BigIntegerField(blank=True, null=True)

    objects = _ContentNodeManager()
    tracked_fields = ["headnote"]

    # Stores the number of ‘read’ characters in a content
    # Length of content, less elided text and html tags.
    reading_length = models.IntegerField(null=True)

    class Meta:
        indexes = [
            models.Index(fields=["casebook", "ordinals"]),
            models.Index(fields=["resource_type", "resource_id"]),
        ]
        ordering = ["ordinals"]

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
        if hasattr(self, "_resource_prefetched") and not self._resource_prefetched:
            if not self.resource_id:
                return None
            if self.resource_type in ["TextBlock", "Link", "LegalDocument"]:
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
        filter_map = {"casebook_id": self.casebook_id, first_ordinals: self.ordinals}
        res = ContentNode.objects.filter(**filter_map).exclude(id=self.id)
        return res

    def rendered_header(self):
        if self.is_resource and self.resource_type == "LegalDocument":
            return render_to_string(
                self.resource.header_template, {"legal_doc": self.resource, "resource": self}
            )
        return ""

    def export_postprocess(self, body, export_options=None):
        if self.resource_type == "LegalDocument":
            api_model = self.resource.source.api_model()
            if hasattr(api_model, "postprocess_content"):
                return api_model.postprocess_content(body, self.id, export_options=export_options)
        return body

    def headerless_export_content(self, request):
        if self.resource_type == "TextBlock":
            return rich_text_export(self.resource.content, request=request, id_prefix=str(self.id))
        return prefix_ids_hrefs(self.resource.content, str(self.id))

    def export_content(self, request):
        if self.resource_type == "LegalDocument":
            contents = prefix_ids_hrefs(self.resource.content, str(self.id))
            header = self.rendered_header()
            return f"{header}{contents}"
        elif self.resource_type == "TextBlock":
            return rich_text_export(self.resource.content, request=request, id_prefix=str(self.id))
        return self.resource.content

    @property
    def is_temporary(self):
        return self.resource_type == "Temp"

    @property
    def can_publish(self):
        return self.casebook.can_publish

    @property
    def has_body(self):
        return bool(
            self.resource_type and self.resource_type != "Temp" and self.resource_type != "Section"
        )

    @property
    def provides_header(self):
        return not (
            self.resource_type is None or self.resource_type in {"Section", "TextBlock", "Link"}
        )

    @property
    def body(self):
        return (self._resource or self.resource) if self.has_body else None

    @property
    def body_template(self):
        if not self.has_body:
            return "includes/bodies/empty.html"
        return {
            "Link": "includes/bodies/link.html",
            "TextBlock": "includes/bodies/text_block.html",
            "LegalDocument": "includes/bodies/legal_doc.html",
        }[self.resource_type]

    def identify_headnote_type(self):
        if not self.headnote:
            return "Text"
        pq = PyQuery(self.headnote)
        if pq("embed") or pq("img") or pq("iframe"):
            return "Multimedia"
        return "Text"

    @property
    def doc_class(self):
        if not self.resource_type or self.resource_type == "Section":
            return "Section"
        if self.resource_type == "TextBlock":
            if self.resource.doc_class == "Text" and self.headnote_doc_class == "Text":
                return "Text"
            return (
                (self.resource.doc_class != "Text" and self.resource.doc_class)
                or (self.headnote_doc_class != "Text" and self.headnote_doc_class)
                or "Text"
            )
        if self.resource_type == "LegalDocument":
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
            if self.doc_class in ["Section", "Text", "Multimedia"]:
                return "Chapter"
            return "Leading Resource"
        elif self.doc_class == "Section":
            if depth == 2:
                return "Section"
            return "Subsection"
        return "Resource"

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
        cleanse_html_field(self, "headnote", True)
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
        if self.resource_type in ["", "Section", None]:
            self._delete_related_links_and_text_blocks()
            child_total, child_deletes = self.contents.delete()
        elif self.resource_type in ["TextBlock", "Link"]:
            child_total, child_deletes = self.resource.delete()

        # Delete this node
        return_total, return_dict = super().delete(*args, **kwargs)

        # Update the ordinals of the content tree
        parent.content_tree__repair()

        for k, v in child_deletes.items():
            return_dict[k] = return_dict.get(k, 0) + v
        return (return_total + child_total, return_dict)

    def _delete_related_links_and_text_blocks(self):
        """
        A private utility for efficiently deleting associated Link and TextBlock objects.
        """
        if self.type != "section":
            raise NotImplementedError

        to_delete = {Link: [], TextBlock: []}
        for resource in self.contents.prefetch_resources():
            if resource.resource_id and resource.resource_type in ("Link", "TextBlock"):
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
        filter_map = {"casebook_id": self.casebook_id, first_ordinals: self.ordinals}
        return ContentNode.objects.filter(**filter_map).exclude(id=self.id)

    @property
    def annotatable(self):
        """
        Only particular kinds of resources can be annotated.
        """
        return self.type == "resource" and self.resource_type in ["TextBlock", "LegalDocument"]

    def get_annotate_url(self):
        """
        If a resource can be annotated, returns the URL for the page an author
        uses to make annotations. Otherwise, returns a ValueError.
        """
        if self.annotatable:
            return reverse("annotate_resource", args=[self.casebook, self])
        raise ValueError("Only Resources (LegalDocument and TextBlock) can be annotated.")

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
        if not self.resource_type or self.resource_type == "Section":
            return "section"
        elif self.resource_type == "Temp":
            return "temp"
        else:
            return "resource"

    def export(
        self,
        include_annotations,
        file_type="docx",
        export_options=None,
        is_child=False,
        docx_footnotes=None,
    ):
        """
        Export this node and children as docx, or as html for conversion by pandoc.

        Given:
        >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

        Export uses 8 queries: selecting descendant nodes, and prefetching ContentAnnotation, Case, TextBlock, and Link, and provenance info
        >>> with assert_num_queries(select=12, delete=1, insert=1):
        ...     file_data = full_casebook.export(include_annotations=True)
        """

        docx_sections = (
            export_options["docx_sections"]
            if export_options and "docx_sections" in export_options
            else settings.FORCE_DOCX_SECTIONS
        )

        # prefetch all child nodes and related data
        if LiveSettings.load().prevent_exports:
            logger.info(
                f"Exporting Casebook {self.id}: attempt rejected (too many previous failures)"
            )
            return None

        docx_footnotes = (
            docx_footnotes if docx_footnotes is not None else settings.FORCE_DOCX_FOOTNOTES
        )

        children = (
            list(self.contents.prefetch_resources().prefetch_related("annotations"))
            if type(self) is not Resource
            else None
        )

        current_collaborators = set(self.casebook.primary_authors)
        cloned_from = {
            cn.casebook
            for cn in self.ancestor_nodes.prefetch_related("casebook")
            .prefetch_related("casebook__contentcollaborator_set")
            .prefetch_related("casebook__contentcollaborator_set__user")
            if set(cn.casebook.primary_authors) ^ current_collaborators
        }

        # render html
        if not self.resource_type or self.resource_type == "Section":
            template_name = "export/section.html"
        elif self.resource_type == "Temp":
            template_name = "export/tbd.html"
        else:
            template_name = "export/node.html"

        if not docx_sections:
            template_name = template_name.replace("export/", "export/old_pr1491/")

        html = render_to_string(
            template_name,
            {
                "is_export": True,
                "is_child": is_child,
                "node": self,
                "children": children,
                "include_annotations": include_annotations,
                "export_options": export_options,
                "export_date": datetime.now().strftime("%Y-%m-%d"),
                "cloned_from": cloned_from,
            },
        )

        if file_type == "html":
            return html
        if not LiveSettings.export_is_rate_limited():
            return export_via_aws_lambda(
                self, html, file_type, docx_footnotes=docx_footnotes, docx_sections=docx_sections
            )
        logger.info(f"Exporting {self.type} {self.id} prevented due to rate limits")
        return None

    def headnote_for_export(self, export_options=None):
        r"""
        Return headnote HTML prepared for pandoc export.

        >>> assert Resource(headnote='<p>An image <img src=""></p>').headnote_for_export() == '<p>An image <img src=""></p>'
        """
        if not self.headnote:
            return ""
        html = rich_text_export(
            self.headnote,
            request=export_options and export_options.get("request"),
            id_prefix=str(self.id),
        )
        return mark_safe(html)

    @staticmethod
    def update_tree_for_export(tree, export_options=None):
        """
        Prepare an lxml tree (annotated or un-annotated) for export.
        """
        tree = PyQuery(tree)

        # Case Header styling
        for pq in tree(
            'section.head-matter p, center, p[style="text-align:center"], p[align="center"]'
        ).items():
            pq.wrap("<div data-custom-style='Case Header'></div>")
        for el in tree(
            'section.head-matter h4, center h2, h2[style="text-align:center"], h2[align="center"]'
        ):
            el.tag = "div"
            el.attrib["data-custom-style"] = "Case Header"

        return tree

    def content_for_export(self, export_options=None):
        r"""
        Return content as html for export to Pandoc, without annotations.

        >>> resource, *_ = [getfixture(f) for f in ['resource']]
        >>> resource.resource.content = '<center>Title</center><h2 align="center">Subtitle</h2><p>An image <img src=""></p>'
        >>> output = '<header class="case-header">\n</header>\n<div><center>Title</center><h2 align="center">Subtitle</h2><p>An image <img src=""></p></div>'
        >>> assert resource.content_for_export() == output
        """
        html = self.export_content(export_options and export_options.get("request"))
        return mark_safe(html)

    @property
    def num_links(self):
        if self.type == "resource" and self.resource_type == "Link":
            return 1
        if self.type == "section":
            return len(
                [1 for cn in self.contents if cn.type == "resource" and cn.resource_type == "Link"]
            )
        return 0

    @property
    def reading_time(self):
        r"""
        Returns estimated reading time for content in this node.

        Given:
        >>> annotations_factory, *_ = [getfixture(f) for f in ['annotations_factory']]
        >>> input = '''<p>
        ...     [note my note]Has a note[/note]
        ...     [highlight]is highlighted[/highlight]
        ...     [elide]is elided but longer to tell the difference[/elide]
        ...     [replace new content]is replaced[/replace]
        ...     [correction replaced content]is replaced[/correction]
        ...     [link http://example.com]is linked[/link]
        ... </p>'''
        >>> def r_t(text):
        ...     content_node = annotations_factory('LegalDocument', text)[1]
        ...     return content_node.reading_time

        Basic example:
        >>> assert round(r_t(input), 3) == 0.084

        Elisions and HTML tags should also be handled correctly --- elided
        text should not increase the reading time, and text-less annotations
        should not increase it either.
        Each elision will increase reading time by 1/200 seconds, because of
        6 extra characters ('[...] '), but I will declare this negligible.
        >>> elide_test = '''<p>
        ...     [note my note]Has a note[/note]
        ...     [highlight]is highlighted[/highlight]
        ...     is elided
        ...     [replace new content]is replaced[/replace]
        ...     [correction replaced content]is replaced[/correction]
        ...     [link http://example.com]is linked[/link]
        ... </p>'''
        >>> assert r_t(elide_test) != r_t (input)
        >>> hl_test = '''<p>
        ...     [note my note]Has a note[/note]
        ...     is highlighted
        ...     [elide]is elided[/elide]
        ...     [replace new content]is replaced[/replace]
        ...     [correction replaced content]is replaced[/correction]
        ...     [link http://example.com]is linked[/link]
        ... </p>'''
        >>> assert r_t(hl_test) == r_t (input)
        """
        if self.type == "section":
            return sum([cn.reading_time or 0 for cn in self.contents if cn.type != "section"])
        if self.resource_type not in ("LegalDocument", "TextBlock"):
            return None
        if self.reading_length is None:
            self.reading_length = self.calculate_reading_length()
            self.save()
        chars_per_word = 6
        words_per_minute = 200
        return self.reading_length / (chars_per_word * words_per_minute)

    def calculate_reading_length(self):
        # Assuming ~200 wpm reading rate for dense text
        # 240 estimated as per:
        # http://crr.ugent.be/papers/Brysbaert_JML_2019_Reading_rate.pdf
        # get rendered html, without annotations in content
        try:
            html_out = self.annotated_content_for_export()
        except AttributeError:
            return None
        text = parse_html_fragment(html_out).text_content()
        return len(text)

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
            >>> expected = '''<header class="case-header">
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

            >>> expected = '<header class="case-header">\n</header><p><span class="annotate highlighted" data-custom-style="Highlighted Text">One <span class="annotate">two</span></span>' \
            ...     '<span class="annotate"> three</span><span data-custom-style="Footnote Reference">*</span></p>'
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
        doc = self.headerless_export_content(export_options and export_options.get("request"))
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
            annotations.append(
                (min(annotation.global_start_offset, max_valid_offset), True, annotation)
            )
            annotations.append(
                (min(annotation.global_end_offset, max_valid_offset), False, annotation)
            )
        # sort by first two fields, so we're ordered by offset, then we get end tags and then start tags for a given offset
        annotations.sort(key=lambda a: (a[0], not a[1]))
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
                self.skip_next_wrap_before = (
                    False  # whether to apply wrap_before_tags to the next element emitted
                )

                # output state:
                self.out_handler = (
                    lxml.sax.ElementTreeContentHandler()
                )  # the sax ContentHandler that will be used to generate the output
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
                    self.wrap_after_tags
                    and
                    # ... previous tag was closing a block-level element
                    self.prev_tag
                    and self.prev_tag[0] == self.out_handler.endElement
                    and self.prev_tag[1] in block_level_elements
                    and
                    # ... text after tag is whitespace
                    re.match(r"\s*$", data)
                    and
                    # ... the text is not annotated
                    ((not annotations) or end_offset < annotations[0][0])
                ):
                    # remove the open spans added by the previous /tag
                    self.out_ops = self.out_ops[: -len(self.wrap_after_tags)]
                    # prevent spans from closing before the next tag
                    self.skip_next_wrap_before = True

                # Process each annotation within this character range.
                # Include end annotations that come after the final character of the string, but NOT start annotations,
                # so that annotations tend to go inside block tags -- start annotations go to the right of tags
                # and end annotations go to the left.
                while annotations and (
                    end_offset > annotations[0][0]
                    or (end_offset == annotations[0][0] and not annotations[0][1])
                ):
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
                    if kind == "replace" or kind == "elide":
                        # replace/elide tags are simpler because we don't need to do anything special for annotations
                        # that span paragraphs. Just emit the elision text and increment elide when opening the tag,
                        # and decrement when closing. Use a counter for elide instead of a boolean so we handle
                        # overlapping elision ranges correctly (though those shouldn't happen in practice).
                        if is_start_tag:
                            self.out_ops.append(
                                (
                                    self.out_handler.startElement,
                                    "span",
                                    {
                                        "data-custom-style": "Elision"
                                        if kind == "elide"
                                        else "Replacement Text"
                                    },
                                )
                            )
                            self.addText(annotation.content or "" if kind == "replace" else "[ … ]")
                            self.out_ops.append((self.out_handler.endElement, "span"))
                            self.elide += 1
                        else:
                            self.elide = max(self.elide - 1, 0)  # decrement, but no lower than zero
                    elif kind == "correction":
                        if is_start_tag:
                            self.elide += 1
                            self.addText(annotation.content or "")
                        else:
                            self.elide = max(self.elide - 1, 0)  # decrement, but no lower than zero
                    else:  # kind == 'link' or 'note' or 'highlight'
                        # link/note/highlight tags require wrapping all subsequent text in <span> tags.
                        # In addition to emitting the open tags themselves, also add the open and close tags to
                        # wrap_before_tags and wrap_after_tags so that every tag we encounter can be wrapped with
                        # close and open tags for all open annotations.
                        if is_start_tag:
                            # get correct open and close tags for this annotation:
                            if kind == "link":
                                open_tag = (
                                    self.out_handler.startElement,
                                    "a",
                                    {"href": annotation.content, "class": "annotate"},
                                )
                                close_tag = (self.out_handler.endElement, "a")
                            elif kind == "note":
                                open_tag = (
                                    self.out_handler.startElement,
                                    "span",
                                    {"class": "annotate"},
                                )
                                close_tag = (self.out_handler.endElement, "span")
                            elif kind == "highlight":
                                open_tag = (
                                    self.out_handler.startElement,
                                    "span",
                                    {
                                        "class": "annotate highlighted",
                                        "data-custom-style": "Highlighted Text",
                                    },
                                )
                                close_tag = (self.out_handler.endElement, "span")
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
                            if kind == "note" or kind == "link":
                                self.footnote_index += 1
                                footnote_ref = "Footnote Reference" + (
                                    f"-{postfix_id}"
                                    if export_options
                                    and export_options.get("docx_footnotes", False)
                                    else ""
                                )
                                self.out_ops.append(
                                    (
                                        self.out_handler.startElement,
                                        "span",
                                        {"data-custom-style": footnote_ref},
                                    )
                                )
                                self.addText("*" * self.footnote_index)
                                self.out_ops.append((self.out_handler.endElement, "span"))

                # emit any text that comes after the final annotation in this text string:
                if data and not self.elide:
                    self.addText(data)

            def startElementNS(self, name, qname, attributes):
                """Handle opening elements from the source HTML."""
                if self.omitTag(name[1]):
                    return
                if attributes and (None, "data-extra-export-offset") in attributes:
                    extra_offset = int(attributes.getValueByQName("data-extra-export-offset"))
                    self.offset -= extra_offset
                self.addTag(
                    (
                        self.out_handler.startElement,
                        name[1],
                        {k[1]: v for k, v in attributes.items()},
                    )
                )

            def endElementNS(self, name, qname):
                """Handle closing elements from the source HTML."""
                if self.omitTag(name[1]):
                    return
                self.addTag((self.out_handler.endElement, name[1]))

            ## helpers

            def addTag(self, tag):
                """Add a tag from the source HTML, wrapped with the currently open annotation tags."""
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
                """Render and return the lxml content tree from out_handler."""
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
        return mark_safe(
            self.rendered_header()
            + self.export_postprocess(
                html.tostring(dest_tree).decode("utf-8"), export_options=export_options
            )
        )

    def footnote_annotations(self, export_options=None):
        postfix_id = self.id
        style = "Footnote Text" + (
            f"-{postfix_id}"
            if export_options and export_options.get("docx_footnotes", False)
            else ""
        )
        return mark_safe(
            "".join(
                format_html(
                    '<div data-custom-style="{}"><span data-custom-style="Footnote Ref">{}</span> {} </div>',
                    style,
                    "*" * (i + 1),
                    annotation.content,
                )
                for i, annotation in enumerate(
                    a
                    for a in self.annotations.all()
                    if a.global_start_offset >= 0 and a.kind in ("note", "link")
                )
            )
        )

    def is_transmutable(self):
        if self.headnote and len(self.headnote) > 0 or self.provenance:
            return False
        if self.resource_type == "Temp" or self.resource_type == "Unknown":
            return True
        if not self.resource_type or self.resource_type == "Section" or self.resource_type == "":
            self.content_tree__load()
            return len(self.children) == 0
        else:
            if self.annotatable and self.is_annotated():
                return False
            if self.resource_type == "TextBlock":
                try:
                    self.resource
                except ContentNode.DoesNotExist:
                    return True
                return self.resource and len(self.resource.content) < 10  # Reasonable heuristic?
            elif self.resource_type == "Case":
                return True
            elif self.resource_type == "Link":
                return True

    @property
    def primary_authors(self):
        return self.casebook.primary_authors

    @property
    def originating_authors(self):
        if self.type == "Section":
            originating_nodes = set(
                [
                    cloned_node
                    for child_content in self.contents.all()
                    for cloned_node in child_content.provenance
                ]
            )
        else:
            if not self.provenance:
                return set()
            originating_nodes = set(self.provenance)
        users = [
            collaborator.user
            for cn in ContentNode.objects.filter(id__in=originating_nodes)
            .select_related("casebook")
            .prefetch_related("casebook__contentcollaborator_set__user")
            .all()
            for collaborator in cn.casebook.contentcollaborator_set.order_by("id").all()
            if collaborator.has_attribution and collaborator.user.attribution != "Anonymous"
        ]
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
            return any(node.annotations for node in self.contents.prefetch_related("annotations"))

    # URLs

    def get_absolute_url(self):
        """
        Since Sections, and Resources can all be accessed
        from URLs that include slugs AND from urls that omit slugs,
        instruct Django how to calculate the canonical URL for each object.
        https://docs.djangoproject.com/en/2.2/ref/models/instances/#get-absolute-url
        """
        if self.resource_id or self.resource_type == "Temp":
            return reverse("resource", args=[self.casebook, self])
        else:
            return reverse("section", args=[self.casebook, self])

    def get_edit_url(self):
        """
        A convenience method, for retrieving the edit URL of a
        Section, or Resource without having to specify the view name,
        which is useful in shared templates.
        """
        if self.resource_id or self.resource_type == "Temp":
            return reverse("edit_resource", args=[self.casebook, self])
        else:
            return reverse("edit_section", args=[self.casebook, self])

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
        target_casebook.clone_nodes(
            ([self] if type(self) is not Casebook else []) + contents, append=True
        )

    @property
    def in_edit_state(self):
        return self.casebook.in_edit_state

    def tabs_for_user(self, user, current_tab=None):
        read_tab = "Preview" if self.in_edit_state else "Read"
        if current_tab is None:
            current_tab = read_tab
        tabs = [
            ("Casebook", reverse("casebook", args=[self.casebook]), True),
            (
                "Edit",
                reverse("edit_resource", args=[self.casebook, self]),
                self.in_edit_state and self.editable_by(user),
            ),
            (
                "Annotate",
                reverse("annotate_resource", args=[self.casebook, self]),
                self.in_edit_state and self.editable_by(user) and self.annotatable,
            ),
            (read_tab, reverse("section", args=[self.casebook, self]), True),
            ("Credits", reverse("show_resource_credits", args=[self.casebook, self]), True),
        ]
        return [(n, l, n == current_tab) for n, l, c in tabs if c]

    @property
    def descendant_nodes(self):
        ids = [cn.id for cn in self.contents.all()] + [self.id]
        return ContentNode.objects.filter(provenance__overlap=ids).filter(casebook__state="Public")

    @property
    def ancestor_nodes(self):
        ids = [p for cn in self.contents.all() for p in cn.provenance] + [
            p for p in self.provenance
        ]
        return ContentNode.objects.filter(id__in=ids).filter(casebook__state="Public")

    @property
    def related_docs(self):
        docs = None
        if self.resource_type == "LegalDocument":
            docs = [self]
        else:
            docs = [
                x for x in self.contents.filter(resource_type="LegalDocument").prefetch_resources()
            ]

        src_refs = {(doc.resource.source_id, doc.resource.source_ref) for doc in docs}
        legal_doc_sources = {src for src, _ in src_refs}
        legal_doc_refs = {ref for _, ref in src_refs}

        lds = {
            ld.id
            for ld in LegalDocument.objects.filter(
                source_id__in=legal_doc_sources, source_ref__in=legal_doc_refs
            ).all()
            if (ld.source_id, ld.source_ref) in src_refs
        }
        return (
            ContentNode.objects.filter(resource_type="LegalDocument", resource_id__in=lds)
            .filter(casebook__state="Public")
            .prefetch_related("casebook")
        )


#
# Start ContentNode Proxies
#


class Section(ContentNode):
    class Meta:
        proxy = True


class Resource(ContentNode):
    class Meta:
        proxy = True


#
# End ContentNode Proxies
#


class CommonTitle(BigPkModel):
    """
    Commonly referred to as 'series', a many-to-many relationship among casebooks
    where a single casebook is designated as the current edition
    """

    name = models.CharField(max_length=300, blank=False, null=False)
    public_url = models.CharField(
        max_length=300, blank=False, null=False, validators=[validate_unicode_slug]
    )
    current = models.ForeignKey(
        "Casebook", on_delete=models.DO_NOTHING, blank=False, null=False, related_name="title_name"
    )

    class Meta:
        managed = True

    def public_casebooks(self):
        return (
            Casebook.objects.filter(common_title=self)
            .exclude(state=Casebook.LifeCycle.ARCHIVED.value)
            .exclude(state=Casebook.LifeCycle.DRAFT.value)
            .exclude(state=Casebook.LifeCycle.PREVIOUS_SAVE.value)
        )


class CasebookEditLog(BigPkModel):
    casebook = models.ForeignKey(
        "Casebook", on_delete=models.DO_NOTHING, blank=False, null=False, related_name="edit_log"
    )

    entry_date = models.DateTimeField(auto_now_add=True, blank=False, null=False)

    class ChangeType(Enum):
        REMOVED = "Removed"
        ADDED = "Added"
        EDITED = "Edited"
        ANNOTATED = "Annotated"
        ORIGINAL_PUBLISH = "First"

    change = models.CharField(max_length=10, choices=[(tag.value, tag.name) for tag in ChangeType])
    # This is a pointer to the content we direct people to on the history page.
    # It may result in a redirect if there's been more than one edit. Updated on GC.
    content = models.ForeignKey(
        "ContentNode", on_delete=models.SET_NULL, blank=True, null=True, related_name="edit_log"
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
        elif self.change == CasebookEditLog.ChangeType.ORIGINAL_PUBLISH.value:
            line = "Casebook first published."
        return mark_safe(line)


def cover_image_path(instance, filename):
    extension = filename.split(".")[-1]
    return f"cover_images/{instance.id}.{extension}"


class Casebook(EditTrackedModel, TimestampedModel, BigPkModel, TrackedCloneable):
    old_casebook = models.ForeignKey(
        "ContentNode",
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name="replacement_casebook",
    )
    title = models.CharField(max_length=10000, default="Untitled")
    subtitle = models.CharField(max_length=10000, blank=True, null=True)
    headnote = models.TextField(blank=True, null=True)
    description = models.TextField(blank=True, null=True, validators=[MaxLengthValidator(750)])
    cover_image = models.FileField(
        storage=image_storage, upload_to=cover_image_path, blank=True, null=True
    )

    collaborators = models.ManyToManyField(
        "User", through="ContentCollaborator", related_name="casebooks"
    )

    @property
    def contentcollaborator_set(self):
        return self.contentcollaborator_set

    @property
    def attributed_authors(self):
        primary_set = set(self.primary_authors)
        return self.primary_authors + [x for x in self.originating_authors if x not in primary_set]

    class LifeCycle(Enum):
        PRIVATELY_EDITING = "Fresh"  # There is no public version of this casebook
        NEWLY_CLONED = "Clone"  # There is no public version of this casebook
        DRAFT = "Draft"  # This version is private, but a public version exists
        PUBLISHED = "Public"  # This version is public
        ARCHIVED = "Archived"  # This is retired, and is no longer public
        REVISING = "Revising"  # A public and private (with edits) version of this casebook exist. This is the public one
        PREVIOUS_SAVE = "Previous"  # A casebook that has been replaced with a merged draft

    state = models.CharField(max_length=10, choices=[(tag.value, tag.name) for tag in LifeCycle])
    draft = models.OneToOneField(
        "self",
        on_delete=models.DO_NOTHING,
        blank=True,
        null=True,
        related_name="draft_of",
        unique=True,
    )
    history = HistoricalRecords()
    common_title = models.ForeignKey(
        "CommonTitle", on_delete=models.SET_NULL, blank=True, null=True, related_name="casebooks"
    )
    export_fails = models.IntegerField(default=0)

    tracked_fields = ["headnote"]

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
        cleanse_html_field(self, "headnote", True)
        super().save(*args, **kwargs)

    def get_slug(self):
        return slugify(self.title)

    def viewable_by(self, user):
        if (not (self.is_archived or self.is_previous_save)) and (
            self.is_public or user.is_superuser
        ):
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
            return ""
        html = rich_text_export(
            self.headnote,
            request=export_options and export_options.get("request", None),
            id_prefix=str(self.id),
        )
        return mark_safe(html)

    @property
    def is_resource(self):
        # This method is called by ContentNode.content_tree__move_to, if the target parent is a Casebook and not a ContentNode.
        return False

    @property
    def is_public(self):
        public_states = {
            x.value for x in [Casebook.LifeCycle.PUBLISHED, Casebook.LifeCycle.REVISING]
        }
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
        return any(node.annotations for node in self.contents.prefetch_related("annotations"))

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
            if resource.resource_id and resource.resource_type in ("Link", "TextBlock"):
                to_delete[type(resource._resource)].append(resource.resource_id)
        for cls, ids in to_delete.items():
            cls.objects.filter(id__in=ids).delete()

    @property
    def sections(self):
        return Section.objects.filter(casebook=self).filter(resource_type__isnull=True)

    @property
    def resources(self):
        return ContentNode.objects.filter(casebook=self, resource_id__isnull=False)

    @property
    def children(self):
        return ContentNode.objects.filter(casebook=self, ordinals__len=1)

    @property
    def sub_sections(self):
        return self.children

    @property
    def reading_time(self):
        return sum((cn.reading_time or 0 for cn in self.children))

    @property
    def num_links(self):
        return sum((cn.num_links or 0 for cn in self.children))

    @property
    def descendant_nodes(self):
        ids = [cn.id for cn in self.contents.all()]
        return ContentNode.objects.filter(provenance__overlap=ids).filter(casebook__state="Public")

    @property
    def ancestor_nodes(self):
        ids = [p for cn in self.contents.all() for p in cn.provenance]
        return ContentNode.objects.filter(id__in=ids).filter(casebook__state="Public")

    @property
    def related_docs(self):
        docs = [x for x in self.contents.filter(resource_type="LegalDocument").prefetch_resources()]
        src_refs = {(doc.resource.source_id, doc.resource.source_ref) for doc in docs}
        legal_doc_sources = {src for src, _ in src_refs}
        legal_doc_refs = {ref for _, ref in src_refs}

        lds = {
            ld.id
            for ld in LegalDocument.objects.filter(
                source_id__in=legal_doc_sources, source_ref__in=legal_doc_refs
            ).all()
            if (ld.source_id, ld.source_ref) in src_refs
        }
        return (
            ContentNode.objects.filter(resource_type="LegalDocument", resource_id__in=lds)
            .filter(casebook__state="Public")
            .prefetch_related("casebook")
        )

    @property
    def previous_saves(self):
        target_provenance = self.provenance + [self.id]
        return Casebook.objects.filter(
            provenance=target_provenance, state=Casebook.LifeCycle.PREVIOUS_SAVE.value
        ).order_by("-updated_at")

    @transaction.atomic
    def restore_from_save(self):
        if not self.state == Casebook.LifeCycle.PREVIOUS_SAVE.value:
            raise ValueError("Bad restore state")
        current_casebook = self.version_tree__parent()
        savepoint = self

        # swap all attributes
        # start with the fields
        for attr in ("title", "subtitle", "headnote"):
            setattr(current_casebook, attr, getattr(savepoint, attr))

        current_casebook._delete_related_links_and_text_blocks()
        (
            cloned_resources,
            cloned_content_nodes,
            cloned_annotations,
        ) = current_casebook.collect_cloning_nodes(node for node in savepoint.contents.all())
        current_casebook.save_and_parent_cloned_resources(cloned_resources)
        for ccn in cloned_content_nodes:
            ccn.provenance.pop()
        bulk_create_with_history(
            cloned_content_nodes,
            ContentNode,
            batch_size=500,
            default_change_reason=f"Restore from {self.id}",
        )
        current_casebook.save_and_parent_cloned_annotations(cloned_annotations)

    def get_absolute_url(self):
        """See ContentNode.get_absolute_url"""
        return reverse("casebook", args=[self])

    @property
    def view_url(self):
        return self.get_absolute_url()

    def get_draft_url(self):
        """See ContentNode.get_draft_url"""
        if self.draft:
            return reverse("edit_casebook", args=[self.draft])
        raise ValueError("This casebook doesn't have a draft.")

    def get_edit_url(self):
        """See ContentNode.get_edit_url"""
        return reverse("edit_casebook", args=[self])

    def editable_by(self, user):
        """See ContentNode.editable_by"""
        if not user.is_authenticated:
            return False
        collabs = self.contentcollaborator_set.filter(user=user).first()
        return user.is_superuser or (collabs and collabs.can_edit)

    @property
    def permits_cloning(self):
        """See ContentNode.permits_cloning"""
        return self.state not in {
            Casebook.LifeCycle.DRAFT.value,
            Casebook.LifeCycle.ARCHIVED.value,
            Casebook.LifeCycle.PREVIOUS_SAVE.value,
        }

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

        # start with the fields
        for attr in ("title", "subtitle", "description", "headnote"):
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

        to_publish = [
            cn for cn in draft.contents.all().prefetch_resources().prefetch_related("annotations")
        ]
        to_retire = [
            cn for cn in parent.contents.all().prefetch_resources().prefetch_related("annotations")
        ]
        swap_map = {}
        significant_edits = []
        for content_node in to_publish:
            if content_node.provenance:
                previous_cn = content_node.provenance.pop()
                swap_map[previous_cn] = content_node
            else:
                # If there's no provenance, it's a new node
                if content_node.is_resource:
                    this_edit = CasebookEditLog(
                        casebook=parent,
                        content=content_node,
                        change=CasebookEditLog.ChangeType.ADDED.value,
                    )
                    significant_edits.append(this_edit)
            content_node.casebook = parent
        for content_node in to_retire:
            if content_node.id in swap_map:
                original = swap_map.pop(content_node.id)
                content_node.provenance.append(original.id)
                if original.is_resource:
                    if (
                        original.resource_type == "Link"
                        and original.resource.url != content_node.resource.url
                    ) or (
                        original.resource_type != "Link"
                        and original.resource.content != content_node.resource.content
                    ):
                        this_edit = CasebookEditLog(
                            casebook=parent,
                            content=original,
                            change=CasebookEditLog.ChangeType.EDITED.value,
                        )
                        significant_edits.append(this_edit)
                    original_annotations = {
                        (x.global_start_offset, x.global_end_offset, x.content)
                        for x in original.annotations.all()
                    }
                    new_annotations = {
                        (x.global_start_offset, x.global_end_offset, x.content)
                        for x in content_node.annotations.all()
                    }
                    if original_annotations != new_annotations:
                        this_edit = CasebookEditLog(
                            casebook=parent,
                            content=original,
                            change=CasebookEditLog.ChangeType.ANNOTATED.value,
                        )
                        significant_edits.append(this_edit)
            else:
                this_edit = CasebookEditLog(
                    casebook=parent,
                    content=content_node,
                    change=CasebookEditLog.ChangeType.REMOVED.value,
                )
                significant_edits.append(this_edit)
            content_node.casebook = draft

        bulk_update_with_history(
            to_publish + to_retire,
            ContentNode,
            ["casebook_id", "provenance"],
            batch_size=500,
            default_change_reason="Draft Merge",
        )
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
        cloned_casebook = clone_model_instance(
            old_casebook,
            public=False,
            old_casebook=None,
            common_title=None,
            provenance=self.provenance + [self.id],
            draft=None,
            state=(
                Casebook.LifeCycle.DRAFT.value
                if draft_mode
                else Casebook.LifeCycle.NEWLY_CLONED.value
            ),
        )
        cloned_casebook.save()

        # If this is a draft, collaborators stay the same,
        # Otherwise, we just add one collaborator (the current_user)
        if draft_mode:
            collaborators = [
                clone_model_instance(c, casebook=cloned_casebook, can_edit=c.can_edit)
                for c in self.contentcollaborator_set.all()
            ]
            ContentCollaborator.objects.bulk_create(
                collaborators
            )  # Currently no History on Collaborators
            self.draft = cloned_casebook
            self.save()
        elif current_user:
            cloned_casebook.add_collaborator(user=current_user, has_attribution=True, can_edit=True)

        cloned_casebook.clone_nodes(
            old_casebook.contents.prefetch_resources()
            .prefetch_related("annotations")
            .select_related("casebook")
            .prefetch_related("casebook__contentcollaborator_set"),
            draft_mode=draft_mode,
        )
        return cloned_casebook

    def collect_cloning_nodes(self, nodes):
        # clone contents
        cloned_resources = {
            TextBlock: [],
            Link: [],
        }  # collect new TextBlocks and Links for bulk_create
        cloned_content_nodes = []  # collect new ContentNodes for bulk_create
        cloned_annotations = []  # collect new ContentAnnotations for bulk_create

        for old_content_node in nodes:
            # clone content_node
            cloned_content_node = clone_model_instance(
                old_content_node,
                old_casebook=None,
                provenance=old_content_node.provenance + [old_content_node.id],
                casebook=self,
            )
            cloned_content_nodes.append(cloned_content_node)

            # clone annotations
            for old_annotation in old_content_node.annotations.all():
                cloned_annotation = clone_model_instance(old_annotation)
                cloned_annotations.append((cloned_annotation, cloned_content_node))

            # clone resources
            if old_content_node.resource_id and old_content_node.resource_type not in {
                "Case",
                "LegalDocument",
            }:
                resource = old_content_node.resource
                cloned_resource = clone_model_instance(resource)
                cloned_resources[type(cloned_resource)].append(
                    (cloned_resource, cloned_content_node)
                )

        return cloned_resources, cloned_content_nodes, cloned_annotations

    def save_and_parent_cloned_resources(self, cloned_resources):
        # save TextBlocks and Links
        for resource_class, resources in cloned_resources.items():
            bulk_create_with_history(
                (r[0] for r in resources),
                resource_class,
                batch_size=500,
                default_change_reason="Clone Create",
            )
            # after saving, update the associated cloned_content_nodes to point to the new resource_ids
            for cloned_resource, cloned_content_node in resources:
                cloned_content_node.resource_id = cloned_resource.id

    def save_and_parent_cloned_annotations(self, cloned_annotations):
        # save ContentAnnotations (first update cloned_annotations to point to the new content_node IDs)
        for cloned_annotation, cloned_content_node in cloned_annotations:
            cloned_annotation.resource = cloned_content_node
        bulk_create_with_history(
            (r[0] for r in cloned_annotations),
            ContentAnnotation,
            batch_size=500,
            default_change_reason="Clone Create",
        )

    @transaction.atomic
    def clone_nodes(self, nodes, draft_mode=False, append=False):
        """
        Helper method to copy a set of nodes and their associated assets to this casebook. See callers for tests.
        If append=True, ordinals will be edited so the new nodes appear after any existing nodes.
        """
        cloned_resources, cloned_content_nodes, cloned_annotations = self.collect_cloning_nodes(
            nodes
        )

        self.save_and_parent_cloned_resources(cloned_resources)

        # save ContentNodes
        if append:
            # offset cloned nodes so they go at the end of the current tree.
            # "offset" is the count of existing top-level content_tree nodes:
            offset = (
                ContentNode.objects.filter(casebook_id=self).aggregate(models.Max("ordinals"))[
                    "ordinals__max"
                ]
                or [0]
            )[0] + 1
            for node in cloned_content_nodes:
                node.ordinals[0] += offset
        bulk_create_with_history(
            cloned_content_nodes, ContentNode, batch_size=500, default_change_reason="Clone Create"
        )
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
        return (
            self.can_transition_to(Casebook.LifeCycle.PUBLISHED) or self.is_draft or self.has_draft
        )

    def can_transition_to(self, target):
        target_value = (hasattr(target, "value") and target.value) or target
        if self.state == target_value:
            return False

        transition_options = {
            (
                Casebook.LifeCycle.PRIVATELY_EDITING.value,
                Casebook.LifeCycle.NEWLY_CLONED.value,
            ): False,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value, Casebook.LifeCycle.DRAFT.value): False,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value, Casebook.LifeCycle.PUBLISHED.value): True,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value, Casebook.LifeCycle.REVISING.value): False,
            (Casebook.LifeCycle.PRIVATELY_EDITING.value, Casebook.LifeCycle.ARCHIVED.value): True,
            (
                Casebook.LifeCycle.PRIVATELY_EDITING.value,
                Casebook.LifeCycle.PREVIOUS_SAVE.value,
            ): True,
            (
                Casebook.LifeCycle.NEWLY_CLONED.value,
                Casebook.LifeCycle.PRIVATELY_EDITING.value,
            ): True,
            (Casebook.LifeCycle.NEWLY_CLONED.value, Casebook.LifeCycle.DRAFT.value): False,
            (Casebook.LifeCycle.NEWLY_CLONED.value, Casebook.LifeCycle.PUBLISHED.value): True,
            (Casebook.LifeCycle.NEWLY_CLONED.value, Casebook.LifeCycle.REVISING.value): False,
            (Casebook.LifeCycle.NEWLY_CLONED.value, Casebook.LifeCycle.ARCHIVED.value): True,
            (Casebook.LifeCycle.NEWLY_CLONED.value, Casebook.LifeCycle.PREVIOUS_SAVE.value): False,
            (Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.PRIVATELY_EDITING.value): False,
            (Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.NEWLY_CLONED.value): False,
            (Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.PUBLISHED.value): True,
            (Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.REVISING.value): False,
            (Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.ARCHIVED.value): False,
            (Casebook.LifeCycle.DRAFT.value, Casebook.LifeCycle.PREVIOUS_SAVE.value): True,
            (Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.PRIVATELY_EDITING.value): True,
            (Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.NEWLY_CLONED.value): False,
            (Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.DRAFT.value): False,
            (Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.REVISING.value): True,
            (Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.ARCHIVED.value): False,
            (Casebook.LifeCycle.PUBLISHED.value, Casebook.LifeCycle.PREVIOUS_SAVE.value): False,
            (Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.PRIVATELY_EDITING.value): True,
            (Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.NEWLY_CLONED.value): False,
            (Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.DRAFT.value): False,
            (Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.PUBLISHED.value): True,
            (Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.ARCHIVED.value): False,
            (Casebook.LifeCycle.REVISING.value, Casebook.LifeCycle.PREVIOUS_SAVE.value): False,
            (Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.PRIVATELY_EDITING.value): True,
            (Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.NEWLY_CLONED.value): False,
            (Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.DRAFT.value): False,
            (Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.PUBLISHED.value): False,
            (Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.REVISING.value): False,
            (Casebook.LifeCycle.ARCHIVED.value, Casebook.LifeCycle.PREVIOUS_SAVE.value): False,
            (
                Casebook.LifeCycle.PREVIOUS_SAVE.value,
                Casebook.LifeCycle.PRIVATELY_EDITING.value,
            ): False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value, Casebook.LifeCycle.NEWLY_CLONED.value): False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value, Casebook.LifeCycle.DRAFT.value): False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value, Casebook.LifeCycle.PUBLISHED.value): False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value, Casebook.LifeCycle.REVISING.value): False,
            (Casebook.LifeCycle.PREVIOUS_SAVE.value, Casebook.LifeCycle.ARCHIVED.value): False,
        }

        return transition_options[(self.state, target_value)]

    def transition_to(self, desired_state):
        target_state = (hasattr(desired_state, "value") and desired_state.value) or desired_state
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

    # Editions
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
        for collab in self.contentcollaborator_set.order_by("id").all():
            if not collab.has_attribution or collab.user.attribution == "Anonymous":
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
        originating_node = set(
            [
                cloned_node
                for child_content in self.contents.all()
                for cloned_node in child_content.provenance
            ]
        )
        users = [
            collaborator.user
            for cn in ContentNode.objects.filter(id__in=originating_node)
            .select_related("casebook")
            .prefetch_related("casebook__contentcollaborator_set__user")
            .all()
            for collaborator in cn.casebook.contentcollaborator_set.all()
            if collaborator.has_attribution and collaborator.user.attribution != "Anonymous"
        ]
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
        collaborator_to_add = ContentCollaborator(
            user=user, casebook_id=self.id, **collaborator_kwargs
        )
        collaborator_to_add.save()

    def export(
        self, include_annotations, file_type="docx", export_options=None, docx_footnotes=None
    ):
        """
        Export this node and children as docx, or as html for conversion by pandoc.

        Given:
        >>> full_casebook, assert_num_queries = [getfixture(f) for f in ['full_casebook', 'assert_num_queries']]

        Export uses 8 queries: selecting descendant nodes, and prefetching ContentAnnotation, LegalDocument, TextBlock, and Link, and provenance info.
        >>> with assert_num_queries(select=12, delete=1, insert=1):
        ...     file_data = full_casebook.export(include_annotations=True)
        """
        docx_footnotes = (
            docx_footnotes if docx_footnotes is not None else settings.FORCE_DOCX_FOOTNOTES
        )
        docx_sections = (
            export_options["docx_sections"]
            if export_options and "docx_sections" in export_options
            else settings.FORCE_DOCX_SECTIONS
        )

        # prefetch all child nodes and related data
        if self.export_embargoed() or LiveSettings.load().prevent_exports:
            logger.info(
                f"Exporting Casebook {self.id}: attempt rejected (too many previous failures)"
            )
            return None
        children = (
            list(self.contents.prefetch_resources().prefetch_related("annotations"))
            if type(self) is not Resource
            else None
        )

        current_collaborators = set(self.casebook.primary_authors)
        cloned_from = {
            cn.casebook
            for cn in self.ancestor_nodes.prefetch_related("casebook")
            .prefetch_related("casebook__contentcollaborator_set")
            .prefetch_related("casebook__contentcollaborator_set__user")
            if set(cn.casebook.primary_authors) ^ current_collaborators
        }

        # render html
        logger.info(f"Exporting Casebook {self.id}: serializing to HTML")
        template_name = (
            "export/casebook.html" if docx_sections else "export/old_pr1491/casebook.html"
        )

        html = render_to_string(
            template_name,
            {
                "is_export": True,
                "node": self,
                "children": children,
                "export_options": export_options,
                "export_date": datetime.now().strftime("%Y-%m-%d"),
                "include_annotations": include_annotations,
                "cloned_from": cloned_from,
            },
        )
        if file_type == "html":
            return html
        if docx_sections:
            html = (
                html.replace("&nbsp;", " ")
                .replace("_h2o_keep_element", "&nbsp;")
                .replace("\xa0", " ")
            )
        if not LiveSettings.export_is_rate_limited():
            return export_via_aws_lambda(
                self, html, file_type, docx_sections=docx_sections, docx_footnotes=docx_footnotes
            )
        logger.info(f"Exporting Casebook {self.id} prevented due to rate limits")
        return None

    def inc_export_fails(self):
        # This function is used to avoid making a copy of the casebook via CasebookHistory
        Casebook.objects.filter(id=self.id).update(export_fails=F("export_fails") + 1)

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
        return (
            ContentCollaborator.objects.filter(can_edit=True, casebook=self)
            .prefetch_related("user")
            .first()
            .user
        )

    def content_tree__load(self):
        ordinal_to_node_map = {}
        top_level_children = []
        for content_node in self.contents.order_by("ordinals").all():
            content_node._content_tree__children = []
            ordinal_to_node_map[content_node.ordinal_coordinate()] = content_node
            parent_ords = [o for o in content_node.ordinals[:-1]]
            parent_key = ".".join(map(str, parent_ords))
            while parent_key and parent_key not in ordinal_to_node_map:
                parent_ords.pop()
                parent_key = ".".join(map(str, parent_ords))
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
        return [
            [max([x.ordinals[-1] for x in self.content_tree__children] or [0]) + 1],
            [max([x.display_ordinals[-1] for x in self.content_tree__children] or [0]) + 1],
        ]

    def content_tree__store(self):
        contents = [x for x in self.content_tree__update_ordinals()]
        """
            Update ordinals in the database for any that need to change, based on nodes that have been moved within
            content_tree__children. It is not valid to add nodes from outside, as their tree values will not be populated.
        """
        bulk_update_with_history(
            contents,
            ContentNode,
            ["ordinals", "display_ordinals"],
            batch_size=500,
            default_change_reason="Tree Repair",
        )

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
            if (
                node.ordinals != correct_ordinals
                or not (node.display_ordinals)
                or node.display_ordinals[-1] != current_display_ordinal
            ):
                node.ordinals = correct_ordinals
                node.display_ordinals = [current_display_ordinal]
                yield node
            if node.content_tree__children:
                yield from node.content_tree__update_ordinals()

    @property
    def in_edit_state(self):
        if self.state == "":
            self.state = Casebook.LifeCycle.PRIVATELY_EDITING.value
            self.save()
        return self.state in {
            Casebook.LifeCycle.NEWLY_CLONED.value,
            Casebook.LifeCycle.DRAFT.value,
            Casebook.LifeCycle.PRIVATELY_EDITING.value,
        }

    @property
    def casebook_color_indicator(self):
        return {
            Casebook.LifeCycle.PRIVATELY_EDITING.value: "casebook-draft",
            Casebook.LifeCycle.NEWLY_CLONED.value: "casebook-draft",
            Casebook.LifeCycle.DRAFT.value: "casebook-draft",
            Casebook.LifeCycle.PUBLISHED.value: "casebook-public casebook-preview",
            Casebook.LifeCycle.ARCHIVED.value: "casebook-archived",
            Casebook.LifeCycle.REVISING.value: "casebook-public",
            Casebook.LifeCycle.PREVIOUS_SAVE.value: "casebook-archived",
        }[self.state]

    def tabs_for_user(self, user, current_tab=None):
        read_tab = "Preview" if self.in_edit_state else "Casebook"
        if current_tab is None:
            current_tab = read_tab
        tabs = [
            (
                "Edit",
                reverse("edit_casebook", args=[self]),
                self.in_edit_state and self.editable_by(user),
            ),
            (read_tab, reverse("casebook", args=[self]), not self.is_archived),
            ("Credits", reverse("show_credits", args=[self]), not self.is_archived),
            (
                "Related",
                reverse("show_related", args=[self]),
                not self.is_archived and user.is_superuser,
            ),
            ("History", reverse("casebook_history", args=[self]), self.viewable_by(user)),
            ("Search Inside", reverse("casebook_search", args=[self]), self.viewable_by(user)),
            ("Settings", reverse("casebook_settings", args=[self]), self.editable_by(user)),
        ]
        return [(n, l, n == current_tab) for n, l, c in tabs if c]

    @property
    def revising(self):
        return self.draft_of

    @property
    def grouped_edit_log(self):
        def change_priority(entry):
            return [
                CasebookEditLog.ChangeType.ORIGINAL_PUBLISH.value,
                CasebookEditLog.ChangeType.ADDED.value,
                CasebookEditLog.ChangeType.REMOVED.value,
                CasebookEditLog.ChangeType.EDITED.value,
                CasebookEditLog.ChangeType.ANNOTATED.value,
            ].index(entry.change)

        qs = self.edit_log.order_by("-entry_date")
        last_date = (None, None, None)
        results = []
        log_line = {}
        for entry in qs.all():
            current_date = (entry.entry_date.year, entry.entry_date.month, entry.entry_date.day)
            if last_date == (None, None, None):
                last_date = current_date
            if current_date != last_date:
                results.append(list(log_line.values()))
                log_line = {}
                last_date = current_date
            current_entry = log_line.get(entry.content and entry.content.title, None)
            if not current_entry:
                log_line[entry.content and entry.content.title] = entry
            elif (
                current_entry.change == CasebookEditLog.ChangeType.REMOVED.value
                and entry.change == CasebookEditLog.ChangeType.ADDED.value
            ):
                log_line.pop(entry.content and entry.content.title)
            else:
                log_line[entry.content and entry.content.title] = min(
                    [current_entry, entry], key=change_priority
                )
        results.append(list(log_line.values()))
        return results


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
        return Resource.objects.filter(resource_id=self.id, resource_type="Link")


class RawContent(TimestampedModel, BigPkModel):
    """Legacy table: https://github.com/harvard-lil/h2o/issues/1044"""

    content = models.TextField(blank=True, null=True)
    source_type = models.CharField(max_length=50, blank=True, null=True)
    source_id = models.BigIntegerField(blank=True, null=True)

    class Meta:
        unique_together = (("source_type", "source_id"),)


class TextBlock(NullableTimestampedModel, AnnotatedModel):
    name = models.CharField(max_length=255)
    description = models.CharField(max_length=5242880, blank=True, null=True)
    content = models.CharField(max_length=5242880, blank=True, null=False, default="")
    doc_class = models.CharField(max_length=40, blank=True, null=True)
    history = HistoricalRecords()

    class Meta:
        indexes = [
            models.Index(fields=["created_at"]),
            models.Index(fields=["name"]),
            models.Index(fields=["updated_at"]),
        ]

    def get_name(self):
        """For consistency, expose name via this method, which is exposed by Link"""
        return self.name

    def identify_type(self):
        if not self.content:
            return "Text"
        pq = PyQuery(self.content)
        if pq("embed") or pq("iframe") or pq("img"):
            return "Multimedia"
        return "Text"

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
        cleanse_html_field(self, "content", True)
        self.doc_class = self.identify_type()
        super().save(*args, **kwargs)

    def related_resources(self):
        return Resource.objects.filter(resource_id=self.id, resource_type="TextBlock")


def validate_unused_prefix(value):
    if value.lower() in set(
        [
            "accounts",
            "archived",
            "casebook",
            "casebooks",
            "cases",
            "pages",
            "resources",
            "robots.txt",
            "sections",
            "users",
            "api",
            "about",
            "privacy-policy",
            "terms-of-service",
            "faq",
            "search",
        ]
    ):
        raise ValidationError(f"{value} is already in use")


class User(NullableTimestampedModel, PermissionsMixin, AbstractBaseUser):
    email_address = models.CharField(max_length=255, unique=True)
    attribution = models.CharField(max_length=255, default="Anonymous", verbose_name="Display name")
    affiliation = models.CharField(max_length=255, blank=True, null=True)
    public_url = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        unique=True,
        validators=[validate_unicode_slug, validate_unused_prefix],
    )
    verified_professor = models.BooleanField(default=False)
    professor_verification_requested = models.BooleanField(default=False)

    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=False)

    # login-tracking fields inherited from Rails authlogic gem
    last_request_at = models.DateTimeField(
        blank=True, null=True, help_text="Time of last request from user (to nearest 10 minutes)"
    )
    login_count = models.IntegerField(
        default=0, help_text="Number of explicit password logins by user"
    )
    current_login_at = models.DateTimeField(
        blank=True, null=True, help_text="Time of most recent password login"
    )
    last_login_at = models.DateTimeField(
        blank=True, null=True, help_text="Time of previous password login"
    )
    current_login_ip = models.CharField(
        max_length=255, blank=True, null=True, help_text="IP of most recent password login"
    )
    last_login_ip = models.CharField(
        max_length=255, blank=True, null=True, help_text="IP of previous password login"
    )
    last_login = None  # type: ignore # disable the Django login tracking field from AbstractBaseUser

    EMAIL_FIELD = "email_address"
    USERNAME_FIELD = "email_address"
    REQUIRED_FIELDS = []  # used by createsuperuser

    objects = BaseUserManager()

    class Meta:
        indexes = [
            models.Index(fields=["affiliation"]),
            models.Index(fields=["attribution"]),
            models.Index(fields=["email_address"]),
            models.Index(fields=["id"]),
            models.Index(fields=["last_request_at"]),
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
        return (
            x
            for x in self.casebooks.exclude(state=Casebook.LifeCycle.ARCHIVED.value)
            .exclude(state=Casebook.LifeCycle.PREVIOUS_SAVE.value)
            .order_by("-updated_at")
            .all()
            if x.directly_editable_by(self)
        )

    @property
    def current_collaborators(self):
        return User.objects.filter(contentcollaborator__casebook__contentcollaborator__user=self)

    @property
    def follows(self):
        followed_casebooks = []
        for cb_follow in (
            self.casebookfollow_set.order_by("created_at")
            .prefetch_related("casebook")
            .prefetch_related("casebook__edit_log")
            .all()
        ):
            cb = cb_follow.casebook
            cb.new_updates = len(
                [x for x in cb.edit_log.all() if x.entry_date >= cb_follow.updated_at]
            )
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
    user.save(
        update_fields=[
            "last_login_at",
            "current_login_at",
            "last_login_ip",
            "current_login_ip",
            "login_count",
        ]
    )


user_logged_in.connect(update_user_login_fields)


class SavedImage(TimestampedModel):
    name = models.CharField(max_length=255, null=True, blank=True)
    external_id = models.UUIDField(unique=True)
    image = models.FileField(storage=image_storage)
    uploaded_by = models.ForeignKey(
        "User", on_delete=models.DO_NOTHING, related_name="saved_images"
    )

    class Meta:
        indexes = [models.Index(fields=["external_id"])]

    @property
    def url(self):
        return reverse("image_url", args=[self.external_id])


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
        minute = current_time.hour * 60 + current_time.minute
        elapsed_minutes = (minute - live_settings.export_last_minute_updated) % 1440
        new_rate = max(
            live_settings.export_average_rate - (elapsed_minutes * settings.EXPORT_RATE_FALLOFF), 0
        )
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


ResourceType = Union[Type[LegalDocument], Type[Link], Type[TextBlock]]
