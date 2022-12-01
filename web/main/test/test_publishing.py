from main.models import Casebook

from django.urls import reverse


def test_publish_new_casebook(private_casebook, client):
    """Newly-composed (private, never-published) casebooks, when published, become public"""
    assert private_casebook.state == Casebook.LifeCycle.PRIVATELY_EDITING.value

    response = client.post(
        reverse("publish", args=[private_casebook]),
        as_user=private_casebook.contentcollaborator_set.first().user,
    )
    assert response.status_code == 200
    private_casebook.refresh_from_db()
    assert private_casebook.is_public


def test_publish_draft(casebook, client):
    """Drafts of already-published casebooks, when published, replace their parent."""

    assert casebook.is_public
    draft = casebook.make_draft()
    draft.title = "new title"
    draft.save()
    assert casebook.title != draft.title

    response = client.post(
        reverse("publish", args=[draft]),
        as_user=casebook.contentcollaborator_set.first().user,
    )
    assert response.status_code == 200
    casebook.refresh_from_db()
    assert casebook.is_public
    assert casebook.title == draft.title
