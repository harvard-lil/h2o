from test.test_helpers import check_response

import pytest
from django.urls import reverse

from conftest import CasebookFactory, LegalDocumentFactory, UserFactory, VerifiedProfessorFactory
from main.models import ContentNode, FullTextSearchIndex, Institution, Link, SearchIndex, TextBlock


def test_search_inside_default(full_casebook, client):
    """Search inside should match legal documents by default"""
    legal_documents = ContentNode.objects.filter(
        casebook=full_casebook, resource_type="LegalDocument"
    )
    FullTextSearchIndex().create_search_index()
    url = reverse("casebook_search", kwargs={"casebook_param": full_casebook})

    titles = [d.title for d in legal_documents]
    assert len(titles) > 0
    check_response(client.get(url), content_includes=titles)
    check_response(client.get(url, {"type": "legal_doc_fulltext"}), content_includes=titles)


@pytest.mark.parametrize("resource_type,resource_class", [["Link", Link], ["TextBlock", TextBlock]])
def test_search_inside_resource(full_casebook, client, resource_type, resource_class):
    """Search inside should match resource titles in the correct tab"""
    resources = resource_class.objects.filter(
        id__in=ContentNode.objects.filter(
            casebook=full_casebook, resource_type=resource_type
        ).values_list("resource_id", flat=True)
    )
    FullTextSearchIndex().create_search_index()
    url = reverse("casebook_search", kwargs={"casebook_param": full_casebook})

    titles = [d.name for d in resources]
    assert len(titles) > 0

    # Search for all resources of the desired type
    search_result = client.get(url, {"type": resource_type.lower(), "q": ""})
    assert len(titles) == len(
        [t for t in search_result.context["results"] if t.category == resource_type.lower()]
    )
    check_response(search_result, content_includes=titles)

    # Search for a specific resource
    search_result = client.get(url, {"type": resource_type.lower(), "q": resources[0].name})
    assert 1 == len(search_result.context["results"])
    assert resources[0].name in [r.metadata["name"] for r in search_result.context["results"]]


def test_search_inside_include_sections(full_casebook, client):
    """Search inside textual resources should include sections"""
    section = full_casebook.contents.filter(resource_type__isnull=True).first()
    FullTextSearchIndex().create_search_index()
    url = reverse("casebook_search", kwargs={"casebook_param": full_casebook})
    search_result = client.get(url, {"type": "textblock", "q": section.title})
    assert 1 == len(search_result.context["results"])


@pytest.mark.parametrize(
    "user_factory_class,results_count",
    [[VerifiedProfessorFactory, 1], [UserFactory, 0], [lambda: None, 0]],
)
def test_search_inside_prof_only(
    full_casebook, resource_factory, client, user_factory_class, results_count
):
    """Full-text search should show results with professor-only content only if the user is a professor"""

    user = user_factory_class()
    prof_only: ContentNode = resource_factory(
        casebook=full_casebook,
        resource_type="TextBlock",
    )
    prof_only.is_instructional_material = True
    prof_only.save()
    full_casebook.content_tree__repair()  # `reverse` in the results template wants valid ordinals to construct a URL

    FullTextSearchIndex().create_search_index()
    url = reverse("casebook_search", kwargs={"casebook_param": full_casebook})
    search_result = client.get(url, {"type": "textblock", "q": prof_only.title}, as_user=user)
    assert results_count == len(search_result.context["results"])


@pytest.mark.parametrize(
    "type,factory_class,metadata_fields",
    [
        ["casebook", CasebookFactory, ("institution", "title", "attribution")],
        ["legal_doc", LegalDocumentFactory, ("citations", "display_name", "effective_date")],
        [
            "user",
            CasebookFactory,  # Creates an author as a side effect
            ("attribution", "institution", "casebook_count"),
        ],
    ],
)
def test_site_search_metadata(type, factory_class, metadata_fields, db):
    """The site search should return the expected metadata for a specific typed search"""
    total_results = 3

    for _ in range(total_results):
        factory_class()

    SearchIndex().create_search_index()

    page, _, _ = SearchIndex().search(type)

    for result in page:
        assert all((result.metadata[field] for field in metadata_fields)) is not None
    assert page.count == total_results


def test_site_search_school_dropdown(
    institution_factory, content_collaborator_factory, casebook_factory, client
):
    """The site search should return a sorted, unique list of institutions in the school dropdown"""

    # Set up a single casebook with two collaborators from different institutions
    casebook = casebook_factory()
    user1 = casebook.collaborators.first()
    user2 = content_collaborator_factory(casebook=casebook).user

    Institution.objects.all().delete()
    institution1 = institution_factory(name="University 1")
    institution2 = institution_factory(name="University 2")
    not_indexed = institution_factory(name="Institution not represented in the search index")

    user1.institution = institution1
    user1.save()
    user2.institution = institution2
    user2.save()

    SearchIndex().create_search_index()

    url = reverse("internal_search")
    resp = client.get(url)

    # We should get one institution item for each collaborator who contributed
    assert set(resp.context["institutions"]) == set(["University 1", "University 2"])

    # If we filter by any of those, we should get the same result
    resp = client.get(url, {"school": institution1.name})
    assert resp.context["results"].count == 1

    resp = client.get(url, {"school": institution2.name})
    assert resp.context["results"].count == 1

    resp = client.get(url, {"school": not_indexed.name})
    assert resp.context["results"].count == 0
