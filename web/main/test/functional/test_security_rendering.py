import pytest
from django.urls import reverse
from pathlib import Path
from main.models import Casebook
from playwright.sync_api import expect


@pytest.mark.xdist_group("functional")
def test_casebook_title_template_is_literal(static_live_server, page, login_as_default):
    book = Casebook.objects.get(pk=1)
    book.title = "Synthetic {{ ''.constructor.constructor('window.__h2oAudit = true')() }}"
    book.save()
    page.goto(static_live_server.url + book.get_absolute_url())
    page.wait_for_function("window.app !== undefined")
    expect(page.locator(".casebook-title")).to_contain_text(book.title)
    assert page.evaluate("window.__h2oAudit") is None


@pytest.mark.xdist_group("functional")
def test_bulk_headnote_cannot_execute_html(static_live_server, page, login_as_default, client):
    book = Casebook.objects.get(pk=1)
    response = client.post(
        reverse("new_from_outline", args=[book]),
        {
            "data": [
                {
                    "title": "Synthetic audit section",
                    "headnote": '<img src="/synthetic-missing-image" onerror="window.__h2oAudit = true">',
                }
            ]
        },
        content_type="application/json",
        as_user=book.testing_editor,
    )
    assert response.status_code == 200
    node = book.contents.get(title="Synthetic audit section")
    page.goto(static_live_server.url + node.get_absolute_url())
    page.wait_for_function("window.app !== undefined")
    expect(page.locator(".headnote img")).not_to_have_attribute("onerror")
    assert page.evaluate("window.__h2oAudit") is None


@pytest.mark.xdist_group("functional")
def test_admin_reporting_titles_are_literal(page):
    source = Path("main/templates/admin/reporting/index.html").read_text()
    renderer = source[
        source.index("        function renderStats(stats)") : source.index("    </script>")
    ]
    page.route(
        "http://audit.test/",
        lambda route: route.fulfill(
            body='<div id="casebooks-by-usage"></div>', content_type="text/html"
        ),
    )
    page.goto("http://audit.test/")
    page.add_script_tag(content=renderer)
    page.evaluate("""() => renderStats({start_date: '2026-01-01', end_date: '2026-01-02', items: [{
        title: '<img src="missing" onerror="window.__h2oAudit = true">', url: '/synthetic',
        authors: [], is_public: true, visits: 1
    }]})""")
    expect(page.locator("#casebooks-by-usage")).to_contain_text("<img src=")
    expect(page.locator("#casebooks-by-usage img")).to_have_count(0)
    assert page.evaluate("window.__h2oAudit") is None


@pytest.mark.xdist_group("functional")
def test_print_author_attribute_is_escaped(static_live_server, page, login_as_default):
    book = Casebook.objects.get(pk=1)
    collab = book.contentcollaborator_set.first()
    collab.has_attribution = True
    collab.save()
    author = collab.user
    author.attribution = '"><script>window.__h2oAudit = true</script><meta content="'
    author.save()
    page.goto(static_live_server.url + reverse("printable_all", args=[book]))
    assert author.attribution in page.locator("meta[name=author]").get_attribute("content")
    assert page.evaluate("window.__h2oAudit") is None


@pytest.mark.xdist_group("functional")
def test_historical_headnote_is_sanitized_without_rewriting(
    static_live_server, page, login_as_default
):
    from main.models import ContentNode

    node = ContentNode.objects.get(pk=1)
    markup = (
        '<p>Historical text</p><img src="/synthetic-missing" onerror="window.__h2oAudit = true">'
    )
    ContentNode.objects.filter(pk=node.pk).update(headnote=markup)
    page.goto(static_live_server.url + node.get_absolute_url())
    expect(page.locator(".headnote")).to_contain_text("Historical text")
    expect(page.locator(".headnote img")).not_to_have_attribute("onerror")
    assert page.evaluate("window.__h2oAudit") is None
    node.refresh_from_db()
    assert node.headnote == markup


@pytest.mark.xdist_group("functional")
@pytest.mark.parametrize("kind", ["note", "replace", "correction"])
def test_reading_annotations_are_plain_text(static_live_server, page, login_as_default, kind):
    from main.models import ContentAnnotation, ContentNode

    node = ContentNode.objects.get(pk=1)
    node.resource.content = "<p>Annotation target text.</p>"
    node.resource.save()
    node.annotations.all().delete()
    content = '<img src="/synthetic-missing" onerror="window.__h2oAudit = true">'
    ContentAnnotation.objects.create(
        resource=node, kind=kind, content=content, global_start_offset=0, global_end_offset=5
    )
    page.goto(static_live_server.url + reverse("printable_all", args=[node.casebook]))
    target = page.locator(".authors-note" if kind == "note" else f"ins.{kind}")
    expect(target).to_have_text(content)
    expect(target.locator("img")).to_have_count(0)
    assert page.evaluate("window.__h2oAudit") is None


@pytest.mark.xdist_group("functional")
@pytest.mark.parametrize("url", ["javascript:window.__h2oAudit=true", "https://[invalid"])
def test_reading_legacy_link_is_inert(static_live_server, page, login_as_default, url):
    from main.models import ContentAnnotation, ContentNode

    node = ContentNode.objects.get(pk=1)
    node.resource.content = "<p>Annotation target text.</p>"
    node.resource.save()
    node.annotations.all().delete()
    ContentAnnotation.objects.create(
        resource=node, kind="link", content=url, global_start_offset=0, global_end_offset=5
    )
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto(static_live_server.url + reverse("printable_all", args=[node.casebook]))
    link = page.locator("section.resource a")
    expect(link).to_have_text("Annot")
    expect(link).not_to_have_attribute("href")
    assert not errors
    assert page.evaluate("window.__h2oAudit") is None
