import pytest
from django.urls import reverse
from playwright.sync_api import expect

from main.models import Casebook, CasebookEditLog, ContentNode


@pytest.mark.xdist_group("functional")
def test_history_titles_are_literal_text(static_live_server, page, login_as_default):
    node = ContentNode.objects.get(pk=1)
    node.title = "{{ missing.fullTitle }} <b>literal title</b>"
    node.save()
    casebook = Casebook.objects.get(pk=1)
    CasebookEditLog.objects.create(casebook=casebook, content=node, change="Edited")
    page.goto(static_live_server.url + reverse("casebook_history", args=[casebook]))
    expect(page.locator(".history-entry")).to_contain_text(node.title)
    expect(page.locator(".history-entry b")).to_have_count(0)
    page.wait_for_function("window.app !== undefined")
    expect(page.locator(".history-entry")).to_contain_text(node.title)
