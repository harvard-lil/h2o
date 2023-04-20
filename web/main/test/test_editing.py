from datetime import datetime
from test.test_helpers import check_response

import pytest
from django.urls import reverse
from pytest_django.asserts import assertContains, assertFormError, assertNotContains

from main.models import ContentNode, LegalDocument


@pytest.fixture
def casebook_or_draft(request):
    """Given a fixture name that corresponds to a casebook, return the casebook's draft if present,
    or the casebook itself if not"""
    casebook = request.getfixturevalue(
        request.param
    )  # Interpret the indirect parameter as a fixture and then run the fixture function
    return casebook.draft if casebook.draft else casebook


@pytest.mark.parametrize(
    "casebook_or_draft", ["full_private_casebook", "full_casebook_with_draft"], indirect=True
)
@pytest.mark.parametrize(
    "resource_type,edit_field,edit_value",
    [
        ["TextBlock", "title", "owner-edited title"],
        ["LegalDocument", "title", "owner-edited title"],
    ],
)
def test_edit_resources(casebook_or_draft, resource_type, edit_field, edit_value, client):
    """Users should be able to edit resource metadata via a web form"""
    resource = casebook_or_draft.contents.filter(resource_type=resource_type).first()
    orig_value = getattr(resource, edit_field)
    check_response(
        client.get(resource.get_edit_url(), as_user=resource.testing_editor),
        content_includes=[orig_value],
    )
    resp = client.post(
        resource.get_edit_url(),
        {edit_field: edit_value},
        as_user=resource.testing_editor,
        follow=True,
    )
    assertContains(resp, edit_value)
    assertNotContains(resp, orig_value)


@pytest.mark.parametrize(
    "casebook_or_draft", ["full_private_casebook", "full_casebook_with_draft"], indirect=True
)
@pytest.mark.parametrize(
    "resource_type,edit_field,edit_value",
    [
        ["TextBlock", "content", "owner-edited content"],
        ["Link", "url", "http://new.example.com"],
    ],
)
def test_edit_subresource(casebook_or_draft, resource_type, edit_field, edit_value, client):
    """Users should be able to edit Link or TextBlock data"""
    resource = casebook_or_draft.contents.filter(resource_type=resource_type).first()
    orig_value = getattr(resource.resource, edit_field)
    edit_value = edit_value
    check_response(
        client.get(resource.get_edit_url(), as_user=resource.testing_editor),
        content_includes=[orig_value],
    )
    post_body = {"title": "Title"}
    post_body[edit_field] = edit_value
    resp = client.post(
        resource.get_edit_url(),
        post_body,
        as_user=resource.testing_editor,
        follow=True,
    )
    assertContains(resp, edit_value)
    assertNotContains(resp, orig_value)


def test_subresource_validation(full_private_casebook, client):
    """Passing invalid data to the subresource form should return a user-visible error"""
    resource = full_private_casebook.contents.filter(resource_type="Link").first()
    new_title = "New title"
    new_url = "http://new.example.com"

    # Ensure that the parent resource isn't modified if the subresource had a validation error
    resp = client.post(
        resource.get_edit_url(),
        {"url": "invalid", "title": new_title},
        as_user=resource.testing_editor,
        follow=True,
    )
    resource.refresh_from_db()
    assert resource.title != new_title
    assertFormError(resp, "embedded_resource_form", "url", "Enter a valid URL.")

    # Both forms must validate before any part of the resource can be saved
    resp = client.post(
        resource.get_edit_url(),
        {"url": new_url, "title": new_title},
        as_user=resource.testing_editor,
        follow=True,
    )
    resource.refresh_from_db()
    assert resource.title == new_title
    resource.resource.refresh_from_db()
    assert resource.resource.url == new_url


def test_add_net_new_resource(full_private_casebook, client, legal_doc_source, mocker):
    """It should be possible to add a new legal document from an upstream source"""
    ref = "test-ref"
    pull = mocker.patch("main.views.LegalDocumentSource.pull")
    pull.return_value = LegalDocument(
        source=legal_doc_source,
        name="",
        citations=[""],
        doc_class="Code",
        updated_date=datetime.now(),
        source_ref=ref,
    )

    assert LegalDocument.objects.filter(source_ref=ref, source=legal_doc_source).count() == 0

    resp = client.post(
        reverse("legal_document_resource_view", args=[full_private_casebook]),
        {
            "source_id": legal_doc_source.id,
            "source_ref": ref,
        },
        as_user=full_private_casebook.testing_editor,
    )
    assert resp.status_code == 201

    # The LegalDocument exists now...
    legal_doc = LegalDocument.objects.get(source_ref=ref, source=legal_doc_source)

    # ...and it's been added to the casebook
    node = ContentNode.objects.get(resource_id=legal_doc.id, resource_type="LegalDocument")

    assert full_private_casebook.contents.get(id=node.id)


def test_only_add_unknown_resource(
    full_private_casebook, client, legal_doc_source, legal_document_factory, mocker
):
    """Never get a new copy of an existing legal document"""
    ref = "test-ref"
    pull = mocker.patch("main.views.LegalDocumentSource.pull")
    pull.return_value = LegalDocument(
        source=legal_doc_source,
        name="",
        citations=[""],
        doc_class="Code",
        source_ref=ref,
    )
    legal_document_factory(source=legal_doc_source, source_ref=ref)

    assert LegalDocument.objects.filter(source_ref=ref, source=legal_doc_source).count() == 1

    client.post(
        reverse("legal_document_resource_view", args=[full_private_casebook]),
        {
            "source_id": legal_doc_source.id,
            "source_ref": ref,
        },
        as_user=full_private_casebook.testing_editor,
    )

    assert LegalDocument.objects.filter(source_ref=ref, source=legal_doc_source).count() == 1


def test_new_resource_unknown_source_ref(client, legal_document, full_private_casebook):
    """The legal document add endpoint should return a 404 if a non-existent source id is passed"""
    assert (
        404
        == client.post(
            reverse("legal_document_resource_view", args=[full_private_casebook]),
            {
                "source_id": -1,
                "source_ref": legal_document.source_ref,
            },
            as_user=full_private_casebook.testing_editor,
        ).status_code
    )


def test_add_new_resource_fails_safely(
    full_private_casebook, client, legal_document_source_factory, mocker
):
    """The legal document add endpoint should return a 404 if it's passed a non-existent upstream doc id"""

    pull = mocker.patch("main.views.LegalDocumentSource.pull")
    pull.return_value = None

    source = legal_document_source_factory()

    assert (
        404
        == client.post(
            reverse("legal_document_resource_view", args=[full_private_casebook]),
            {
                "source_id": source.id,
                "source_ref": "fake id",
            },
            as_user=full_private_casebook.testing_editor,
        ).status_code
    )


def test_add_new_resource_position_section(full_private_casebook, legal_document, client):
    """The legal document endpoint should add the legal doc at the section requested"""

    section = full_private_casebook.contents.filter(resource_type=None).first()

    resp = client.post(
        reverse("legal_document_resource_view", args=[full_private_casebook]),
        {
            "source_id": legal_document.source.id,
            "source_ref": legal_document.source_ref,
            "section_id": section.id,
        },
        as_user=full_private_casebook.testing_editor,
    )
    assert resp.status_code == 201
    last_resource_of_section = section.contents.last()
    assert last_resource_of_section.resource_type == "LegalDocument"
    assert LegalDocument.objects.get(id=last_resource_of_section.resource_id).source_ref == str(
        legal_document.source_ref
    )
    assert last_resource_of_section.id != full_private_casebook.contents.last().id


def test_add_new_resource_position(full_private_casebook, legal_document, client):
    """The legal document endpoint should add the legal doc at the end of the casebook if no section is provided requested"""

    resp = client.post(
        reverse("legal_document_resource_view", args=[full_private_casebook]),
        {
            "source_id": legal_document.source.id,
            "source_ref": legal_document.source_ref,
        },
        as_user=full_private_casebook.testing_editor,
    )
    assert resp.status_code == 201

    last_resource_of_casebook = full_private_casebook.contents.last()
    assert last_resource_of_casebook.resource_type == "LegalDocument"
    assert LegalDocument.objects.get(id=last_resource_of_casebook.resource_id).source_ref == str(
        legal_document.source_ref
    )
