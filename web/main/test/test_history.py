import pytest
from django.urls import reverse
from pytest_django.asserts import assertContains

from main.models import CasebookEditLog, ContentNode


@pytest.mark.django_db
@pytest.mark.parametrize("change", list(CasebookEditLog.ChangeType))
def test_history_after_content_deletion(change, section_factory, casebook_edit_log_factory, client):
    section = section_factory()
    casebook = section.casebook
    entry = casebook_edit_log_factory(casebook=casebook, content=section, change=change.value)
    # Exercise SET_NULL after the referenced content is removed.
    ContentNode.objects.filter(pk=section.pk).delete()
    entry.refresh_from_db()
    assert entry.content is None
    description = entry.description_line
    assert "<a " not in description
    if change == CasebookEditLog.ChangeType.ORIGINAL_PUBLISH:
        assert description == "Casebook first published."
    else:
        assert "no longer available" in description
        assert description.startswith(
            "Annotations changed" if change.value == "Annotated" else change.value
        )
    response = client.get(reverse("casebook_history", args=[casebook]))
    assertContains(response, description)


@pytest.mark.django_db
def test_history_keeps_existing_content_links(section_factory, casebook_edit_log_factory):
    section = section_factory()
    entry = casebook_edit_log_factory(
        casebook=section.casebook, content=section, change=CasebookEditLog.ChangeType.ADDED.value
    )
    assert (
        entry.description_line
        == f"Added <a href='{section.get_absolute_url()}'>{section.title}</a>"
    )
