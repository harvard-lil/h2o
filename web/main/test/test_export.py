from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import pytest
from conftest import LiveSettingsFactory
from django.conf import settings
from django.urls import reverse
from lxml import etree
from main.utils import elements_equal, parse_html_fragment


def assert_docx_equal(path_or_file_a, path_or_file_b):
    """
    Two .docx files are considered equal if all zipped files inside have the same contents, except for docProps/core.xml
    which contains a timestamp.

    This function compares CRCs first, then, if that fails, decodes each zipped file and compares the contents as an xml tree.
    If the trees differ, we recommend running the tests with --pdb to drop into the debugger at the moment of failure,
    and inspecting the differing elements using lxml/etree utilities, e.g.
    ... etree.tostring(e1)
    ... etree.tostring(e2)
    """
    with ZipFile(path_or_file_a) as zip_a, ZipFile(path_or_file_b) as zip_b:
        try:
            # Quick comparison
            assert set(
                (f.filename, f.CRC) for f in zip_a.infolist() if f.filename != "docProps/core.xml"
            ) == set(
                (f.filename, f.CRC) for f in zip_b.infolist() if f.filename != "docProps/core.xml"
            )
        except AssertionError:
            # Slow comparison:
            for filename in [f for f in zip_a.namelist() if f != "docProps/core.xml"]:
                data_a = etree.XML(zip_a.read(filename))
                data_b = etree.XML(zip_b.read(filename))
                assert elements_equal(data_a, data_b, exc_class=AssertionError)


def assert_html_equal(bytes_a, bytes_b):
    # If the trees differ, we recommend running the tests with --pdb to drop into the debugger at the moment of failure,
    # and inspecting the differing elements using lxml/etree utilities, e.g.
    # > etree.tostring(e1, method='html')
    # > etree.tostring(e2, method='html')
    tree_a = parse_html_fragment(bytes_a.decode("utf-8"))
    tree_b = parse_html_fragment(bytes_b.decode("utf-8"))
    assert elements_equal(tree_a, tree_b, ignore_trailing_whitespace=True, exc_class=AssertionError)


@pytest.mark.xdist_group("pandoc-lambda")
def test_export(
    request, casebook_factory, section_factory, annotations_factory, resource_factory, link_factory
):
    """
    This test generates the contents of all exported files in test/files/export/ and compares them to the versions
    on disk.

    To regenerate the files on disk, instead of comparing, run:

        pytest -k test_export --write-files
    """
    write_files = request.config.getoption("--write-files")
    base_path = Path(settings.BASE_DIR, "test/files/export")

    # set up a casebook with an annotated case, annotated textblock, and a link resource
    case_template = """
        <section class="head-matter">
            <p>A Title</p>
        </section>
        <section>
            <p>This text [note my note]has a note</p>
            <p>spanning[/note] paragraphs</p>
            <p>This text [link http://example.com]has a link</p>
            <p>spanning[/link] paragraphs</p>
            <p>This text [highlight]is highlighted</p>
            <p>spanning[/highlight] paragraphs</p>
            <p>This text is elided: [elide]is elided</p>
            <p>and so is this</p>
            <p>and so is this[/elide] but this isn't</p>
            <p>This text is replaced: [replace new content]is replaced</p>
            <p>and so is this</p>
            <p>and so is this[/replace] but this isn't</p>
        </section>"""
    casebook = casebook_factory(
        title="Rules & Regulations", subtitle="A novel.", headnote="<p>Not really a novel.</p>"
    )
    # check that xml entities work in table of contents entries:
    section = section_factory(
        casebook=casebook,
        ordinals=[1],
        title="Ampersand & Ampersand; a fish drawing ><>",
        subtitle="Section subtitle",
        headnote="<p>Section headnote</p>",
    )
    resource = annotations_factory(
        "LegalDocument", case_template, casebook=casebook, ordinals=[1, 1]
    )[1]
    annotations_factory(
        "TextBlock",
        "<p>A textblock with a [highlight]highlight[/highlight].</p>",
        casebook=casebook,
        ordinals=[1, 2],
    )
    resource_factory(casebook=casebook, ordinals=[1, 3], resource_type="Link")

    # export each node and compare with saved results on disk
    for node in [casebook, section, resource]:
        for file_type in ["docx", "html"]:
            for include_annotations in [True, False]:
                file_data = node.export(
                    include_annotations=include_annotations,
                    file_type=file_type,
                    export_options=None,
                )
                if file_type == "html":
                    file_data = file_data.encode("utf8")
                file_name = f"export-{node.__class__.__name__.lower()}-{'with-annotations' if include_annotations else 'no-annotations'}.{file_type}"
                if write_files:
                    base_path.joinpath(file_name).write_bytes(file_data)
                else:
                    comparison_data = base_path.joinpath(file_name).read_bytes()
                    if file_type == "docx":
                        assert_docx_equal(BytesIO(file_data), BytesIO(comparison_data))
                    else:
                        assert_html_equal(file_data, comparison_data)


@pytest.mark.xdist_group("pandoc-lambda")
def test_export_query_count(assert_num_queries, full_casebook):

    with assert_num_queries(select=12, delete=1, insert=1):
        full_casebook.export(include_annotations=True)


@pytest.mark.xdist_group("pandoc-lambda")
def test_export_is_rate_limited(live_settings, full_casebook, resource):
    prior_count = live_settings.export_average_rate
    full_casebook.export(False)
    resource.export(False)
    live_settings.refresh_from_db()
    assert live_settings.export_average_rate == prior_count + 2


def test_printable_html_livesetting_required(admin_user_factory, client, full_casebook):
    """The printable HTML view requires auth and an explicit setting at this time"""

    resp = client.get(
        reverse("as_printable_html", args=[full_casebook]), as_user=admin_user_factory()
    )
    assert 403 == resp.status_code

    # Only when the live setting is enabled should this work
    LiveSettingsFactory(enable_printable_html_export=True)
    resp = client.get(
        reverse("as_printable_html", args=[full_casebook]), as_user=admin_user_factory()
    )
    assert 200 == resp.status_code


def test_printable_html_casebook(admin_user_factory, client, full_casebook):
    """The casebook printable HTML view should prepare a complete casebook for rendering"""
    LiveSettingsFactory(enable_printable_html_export=True)
    resp = client.get(
        reverse("as_printable_html", args=[full_casebook]), as_user=admin_user_factory()
    )
    assert full_casebook == resp.context["casebook"]
