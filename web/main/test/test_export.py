from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import pytest
from django.conf import settings
from django.urls import reverse
from lxml import etree
from main.export import annotated_content_for_export
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
    request,
    casebook_factory,
    section_factory,
    annotations_factory,
    resource_factory,
    user_factory,
    reset_sequences,
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
                    user=user_factory(),
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
def test_export_query_count(assert_num_queries, full_casebook, user_factory):

    user = user_factory()

    with assert_num_queries(select=12, delete=1, insert=1):
        full_casebook.export(include_annotations=True, user=user)


@pytest.mark.xdist_group("pandoc-lambda")
def test_export_is_rate_limited(live_settings, full_casebook, resource, user_factory):

    prior_count = live_settings.export_average_rate
    full_casebook.export(False, user=user_factory())
    resource.export(False, user=user_factory())
    live_settings.refresh_from_db()
    assert live_settings.export_average_rate == prior_count + 2


def test_printable_html_casebook(client, full_casebook):
    """The casebook printable HTML view should prepare a complete casebook for rendering"""
    resp = client.get(
        reverse("as_printable_html", args=[full_casebook]),
        as_user=full_casebook.contentcollaborator_set.first().user,
    )
    assert full_casebook == resp.context["casebook"]


def assert_html_matches(annotated_html: str, expected_html: str):
    assert elements_equal(
        parse_html_fragment(annotated_html),
        parse_html_fragment(expected_html),
        ignore_trailing_whitespace=True,
    ), f"Expected:\n{expected_html}\nGot:\n{annotated_html}"


@pytest.mark.parametrize(
    "input,expected",
    [
        # Notes
        [
            "[note my note]Has a note[/note]",
            '<p><span class="annotate">Has a note</span><span data-custom-style="Footnote Reference">*</span></p>',
        ],
        # Highlights
        [
            "[highlight]is highlighted[/highlight]",
            '<p><span class="annotate highlighted" data-custom-style="Highlighted Text">is highlighted</span></p>',
        ],
        # Elisions
        ["[elide]is elided[/elide]", '<p><span data-custom-style="Elision">[ … ]</span></p>'],
        # Replacements
        [
            "[replace new content]is replaced[/replace]",
            '<p><span data-custom-style="Replacement Text">new content</span></p>',
        ],
        # Corrections
        ["[correction replaced content]is replaced[/correction]", "<p>replaced content</p>"],
        # Links
        [
            "[link http://example.com]is linked[/link]",
            '<p><a class="annotate" href="http://example.com">is linked</a><span data-custom-style="Footnote Reference">*</span></p>',
        ],
    ],
)
def test_annotated_export_simple_markup(input: str, expected: str, annotations_factory):
    """Annotated text should be modified to support downstream exports in the expected format"""

    assert_html_matches(
        annotated_content_for_export(annotations_factory("LegalDocument", input)[1]),
        '<header class="case-header"></header>' + expected,
    )


def test_annotated_export_multiple_footnotes(annotations_factory):
    """Adding two items that can produce footnotes should produce distinct footnote references"""
    output = annotated_content_for_export(
        annotations_factory(
            "LegalDocument",
            """
            [link http://example.com]Example 1[/link]
            [note my note]Example 2[/note]
            """,
        )[1]
    )

    assert '<span data-custom-style="Footnote Reference">*</span>' in output
    assert '<span data-custom-style="Footnote Reference">**</span>' in output


@pytest.mark.parametrize(
    "input,expected",
    [
        [  # Highlights spanning paragraphs
            """<p>Some [highlight] text</p>
    <p>Some <em>text</em></p>
    <p>Some [/highlight] text</p>""",
            """<header class="case-header"></header>
    <div><p>Some <span class="annotate highlighted" data-custom-style="Highlighted Text"> text</span></p>
    <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Some </span><em><span class="annotate highlighted" data-custom-style="Highlighted Text">text</span></em></p>
    <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Some </span> text</p></div>
    """,
        ],
        [  # Replacements spanning paragraphs
            """<p>Some [replace new content] text</p>
            <p>Some <em>text</em> <br></p>
             <p>Some [/replace] text</p>""",
            """<header class="case-header">
                 </header>
            <div><p>Some <span data-custom-style="Replacement Text">new content</span></p><p> text</p></div>
            """,
        ],
    ],
)
def test_annotated_export_spanning_paragraphs(annotations_factory, input: str, expected: str):
    """Annotations should be allowed to span block nodes"""
    input = annotated_content_for_export(
        annotations_factory(
            "LegalDocument",
            input,
        )[1]
    )

    assert_html_matches(input, expected)


def test_annotated_export_void_elements(annotations_factory):
    """Serialization should understand void/self-closing elements"""
    assert_html_matches(
        annotated_content_for_export(
            annotations_factory(
                "LegalDocument",
                """<p> [highlight] <br> [/highlight] </p>""",
            )[1]
        ),
        """<header class="case-header"></header>
            <p> <span class="annotate highlighted" data-custom-style="Highlighted Text"> </span>
            <br>
            <span class="annotate highlighted" data-custom-style="Highlighted Text"> </span> </p>""",
    )


@pytest.mark.parametrize(
    "input,expected",
    [
        [
            """<p>First</p>
            <p>[highlight]Second[/highlight]</p>
            <p>Third</p>""",
            """
        <div>
            <p>First</p>
            <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Second</span></p>
            <p>Third</p>
        </div>""",
        ],
        [
            """<p>First</p>
            <p>[elide]Second[/elide]</p>
            <p>Third</p>""",
            """
        <div>
            <p>First</p>
            <p><span data-custom-style="Elision">[ … ]</span></p>
            <p>Third</p>
        </div>""",
        ],
        [
            """<p>[highlight]First[/highlight]</p>
            <p>[highlight]Sec[/highlight][highlight]ond[/highlight]</p>
            <p>[highlight]Third[/highlight]</p>""",
            """
        <div>
            <p><span class="annotate highlighted" data-custom-style="Highlighted Text">First</span></p>
            <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Sec</span><span class="annotate highlighted" data-custom-style="Highlighted Text">ond</span></p>
            <p><span class="annotate highlighted" data-custom-style="Highlighted Text">Third</span></p>
        </div>""",
        ],
    ],
)
def test_annotated_export_ambiguous_placement(annotations_factory, input: str, expected: str):
    input = annotated_content_for_export(
        annotations_factory(
            "LegalDocument",
            input,
        )[1]
    )

    assert_html_matches(input, '<header class="case-header"></header>' + expected)


@pytest.mark.parametrize(
    "input,expected",
    [
        [
            "<p>[highlight]One [note my note]two[/highlight] three[/note]</p>",
            """<p>
                <span class="annotate highlighted" data-custom-style="Highlighted Text">One 
                    <span class="annotate">two</span>
                </span>
                <span class="annotate"> three</span>
                <span data-custom-style="Footnote Reference">*</span>
            </p>""",
        ],
        [
            "<p>[highlight]One [elide]two[/highlight] three[/elide]</p>",
            """<p>
                <span class="annotate highlighted" data-custom-style="Highlighted Text">One 
                    <span data-custom-style="Elision">[ … ]</span>
                </span>
            </p>""",
        ],
    ],
)
def test_annotated_export_overlapping(annotations_factory, input: str, expected: str):
    """The annotations export should handle overlapping annotations"""
    input = annotated_content_for_export(
        annotations_factory(
            "LegalDocument",
            input,
        )[1]
    )

    assert_html_matches(input, '<header class="case-header"></header>' + expected)


def test_annotated_export_invalid_clamped(annotations_factory):
    """Annotations with invalid offsets are clamped"""

    input = "<p>[highlight]F[/highlight]oo</p>"
    expected = '<header class="case-header">\n</header>\n<p><span class="annotate highlighted" data-custom-style="Highlighted Text">Foo</span></p>'
    resource = annotations_factory("LegalDocument", input)[1]
    resource.annotations.update(global_end_offset=1000)  # move end offset past end of text
    assert annotated_content_for_export(resource) == expected
