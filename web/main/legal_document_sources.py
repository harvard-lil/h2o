#
# Legal Doc Source Types
#

from datetime import datetime

import re

import lxml
import lxml.sax
import requests
from dateutil import parser
from django.conf import settings
from django.contrib.postgres.search import SearchQuery, SearchRank, SearchVector
from pyquery import PyQuery

from main.utils import APICommunicationError, looks_like_case_law_link, looks_like_citation

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
        """Get the document from the upstream provider"""
        from main.models import LegalDocument

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
        from main.models import USCodeIndex

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
                "body": (
                    strip_comments(strip_brs(statute_body["content"]))
                    if statute_body["content"]
                    else ""
                ),
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
        from main.models import LegalDocument

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


class CourtListener:
    details = {
        "name": "CourtListener",
        "short_description": "hello",
        "long_description": "CourtListener searches millions of opinions across hundreds of jurisdictions",
        "link": settings.COURTLISTENER_BASE_URL,
        "search_regexes": [],
        "footnote_regexes": [],
    }

    @staticmethod
    def search(search_params):

        if not settings.COURTLISTENER_API_KEY:
            raise APICommunicationError("A CourtListener API key is required")
        try:
            params = (
                {"citation": search_params.q}
                if looks_like_citation(search_params.q)
                else {"q": search_params.q}
            )
            resp = requests.get(
                f"{settings.COURTLISTENER_BASE_URL}/api/rest/v3/search",
                params,
                headers={"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"},
            )
            resp.raise_for_status()
        except requests.exceptions.HTTPError as e:
            msg = f"Communication with CourtListener failed: {str(e), resp.status_code, resp.request.url}"
            raise APICommunicationError(msg)
        results = []

        for r in resp.json()["results"]:
            results.append(
                {
                    "fullName": r["caseName"],
                    "shortName": r["caseName"],
                    "fullCitations": ", ".join(r["citation"]),
                    "shortCitations": ", ".join(r["citation"][:3])
                    + ("..." if len(r["citation"]) > 3 else ""),
                    "effectiveDate": parser.isoparse(r["dateFiled"]).strftime("%Y-%m-%d"),
                    "url": f"{settings.COURTLISTENER_BASE_URL}{r['absolute_url']}",
                    "id": r["id"],
                }
            )
        return results

    @staticmethod
    def pull(legal_doc_source, id):
        from main.models import LegalDocument

        if not settings.COURTLISTENER_API_KEY:
            raise APICommunicationError("A CourtListener API key is required")
        try:
            resp = requests.get(
                f"{settings.COURTLISTENER_BASE_URL}/api/rest/v3/clusters/{id}/",
                headers={"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"},
            )
            resp.raise_for_status()
            cluster = resp.json()
            resp = requests.get(
                f"{settings.COURTLISTENER_BASE_URL}/api/rest/v3/opinions/{id}/",
                headers={"Authorization": f"Token {settings.COURTLISTENER_API_KEY}"},
            )
            resp.raise_for_status()

            opinion = resp.json()

        except requests.exceptions.HTTPError as e:
            msg = f"Failed call to {resp.request.url}: {e}\n{resp.content}"
            raise APICommunicationError(msg)

        body = opinion["html"]
        case = LegalDocument(
            source=legal_doc_source,
            short_name=cluster["case_name"],
            name=cluster["case_name"],
            doc_class="Case",
            citations=cluster["citations"],
            jurisdiction="",
            effective_date=cluster["date_filed"],
            publication_date=cluster["date_filed"],
            updated_date=datetime.now(),
            source_ref=str(id),
            content=body,
            metadata=None,
        )
        return case

    @staticmethod
    def header_template(legal_document):
        return "empty_header.html"


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
