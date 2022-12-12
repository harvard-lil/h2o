import pytest

from main.templatetags.featured_casebook import featured_casebook


def test_featured_casebook(full_casebook):
    """Featuring a casebook should return information about it, unless overridden"""
    assert featured_casebook(full_casebook.id)["title"] == full_casebook.title
    assert featured_casebook(full_casebook.id, title="Fake title")["title"] == "Fake title"
    assert featured_casebook(full_casebook.id)["error"] is None


def test_featured_casebook_private(private_casebook):
    """A private casebook should return only an error message"""
    assert "not publicly viewable" in featured_casebook(private_casebook.id)["error"]


@pytest.mark.django_db
def test_featured_casebook_missing():
    """Attempting to retrieve a non-existent casebook should return a friendly error message"""
    assert "not found" in featured_casebook(-1)["error"]
