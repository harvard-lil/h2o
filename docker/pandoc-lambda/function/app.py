import boto3
import io
import os
import signal
import subprocess
import tempfile
from docx import Document
from docx.shared import Twips
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn
from docx.enum.section import WD_SECTION_START, WD_HEADER_FOOTER_INDEX, WD_ORIENTATION
from lxml import etree


def lift_footnote(doc, footnotes_part, ref, texts, id, author=False):
    id_att = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}id'
    custom_mark_att = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}customMarkFollows'
    footnote = OxmlElement("w:footnote")
    footnote.attrib[id_att] = id
    doc_insert = OxmlElement("w:footnoteReference")
    doc_insert.attrib[custom_mark_att] = "1"
    doc_insert.attrib[id_att] = id

    # Content
    for t in texts:
        footnote.append(t)

    # Insert into the footnotes file
    footnotes_part.element.append(footnote)

    # Insert the reference into the doc
    ref.insert(1,doc_insert)

def promote_case_footnotes(doc):
    val_att = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val'
    author_footnotes = {}

    for ref in doc.element.xpath("//*[*/w:rStyle[starts-with(@w:val,'FootnoteReference')]]"):
        mark_text = ref.text
        style_node = ref.xpath(".//w:rStyle[starts-with(@w:val,'FootnoteReference')]")[0]
        node_id = style_node.attrib[val_att][18:]
        mark_id = f"{node_id}-{mark_text}"
        if mark_id not in author_footnotes:
            author_footnotes[mark_id] = {'id':mark_id, 'mark': mark_text, 'refs': [], 'texts': []}
        style_node.attrib[val_att] = 'FootnoteReference'
        author_footnotes[mark_id]['refs'].append(ref)

    for text_el in doc.element.xpath("//w:p[w:pPr/w:pStyle[starts-with(@w:val,'FootnoteText')]]"):
        mark_text = text_el.xpath(".//*[*/w:rStyle]/w:t")[0].text
        node_id = text_el.xpath(".//w:pStyle[starts-with(@w:val, 'FootnoteText')]/@w:val")[0][13:]
        mark_id = f'{node_id}-{mark_text}'
        if mark_id not in author_footnotes:
            author_footnotes[mark_id] = {'id':mark_id, 'mark': mark_text, 'refs': [], 'texts': []}
        mark_el = text_el.xpath("./w:pPr/w:pStyle[starts-with(@w:val,'FootnoteText')]")[0]
        mark_el.attrib[val_att] = 'FootnoteText'
        for style in text_el.xpath(".//w:pStyle[starts-with(@w:val, 'FootnoteText')]"):
            style.attrib[val_att] = 'FootnoteText'
        for style in text_el.xpath(".//w:rStyle[starts-with(@w:val, 'FootnoteRef')]"):
            style.attrib[val_att] = 'FootnoteReference'
        author_footnotes[mark_id]['texts'].append([text_el])


    case_footnotes = {}

    for ref in doc.element.xpath("//*[*/w:rStyle[starts-with(@w:val,'CaseFootnoteReference')]]"):
        mark_text = ref.text
        node = ref.xpath(".//w:rStyle[starts-with(@w:val,'CaseFootnoteReference')]")[0]
        node_id = node.attrib[val_att][22:]
        mark_id = f'{node_id}-{mark_text}'
        if mark_id not in case_footnotes:
            case_footnotes[mark_id] = {'id':mark_id, 'mark': mark_text, 'refs': [], 'texts': []}
        node.attrib[val_att] = "FootnoteReference"
        parent = ref.getparent()
        gp = parent.getparent()
        gp.replace(parent, ref)
        case_footnotes[mark_id]['refs'].append(ref)

    for footnote_start in doc.element.xpath("//*[*/*[starts-with(@w:val,'CaseFootnoteText')] and .//w:hyperlink]"):
        mark_text = footnote_start.xpath(".//*[*/w:rStyle]/w:t")[0].text
        node_id = footnote_start.xpath(".//w:pStyle[starts-with(@w:val, 'CaseFootnoteText')]/@w:val")[0][17:]

        current_stack = [footnote_start]
        next_footnote_candidate = footnote_start.getnext()
        style = next_footnote_candidate.xpath(".//w:pStyle/@w:val")
        link = next_footnote_candidate.xpath(".//w:hyperlink//text()")
        while next_footnote_candidate is not None and style and style[0] != 'CaseBody' and not link:
            current_stack.append(next_footnote_candidate)
            next_footnote_candidate = next_footnote_candidate.getnext()
            if next_footnote_candidate.tag == '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}bookmarkStart':
                break
            style = next_footnote_candidate.xpath(".//w:pStyle/@w:val")
            if style:
                style_node = next_footnote_candidate.xpath(".//w:pStyle[starts-with(@w:val,'CaseFootnoteText')]")
                if style_node:
                    style_node[0].attrib[val_att] = 'CaseFootnoteText'
            link = next_footnote_candidate.xpath(".//w:hyperlink//text()")
        mark_id = f'{node_id}-{mark_text}'
        if mark_id not in case_footnotes:
            case_footnotes[mark_id] = {'id':mark_id, 'mark': mark_text, 'refs': [], 'texts': []}
        hl = footnote_start.getchildren()[1]
        footnote_start.xpath(".//w:rStyle")[0].attrib[val_att] = 'FootnoteReference'
        footnote_start.replace(hl, hl.getchildren()[0])
        case_footnotes[mark_id]['texts'].append(current_stack)

    # extract refs and footnotes here.
    fid = 1

    footnote_part = next(f for f in doc.part.package.parts if f.partname=='/word/footnotes.xml')
    footnote_part.element = parse_xml(footnote_part.blob)

    for val in author_footnotes.values():
        for ref,texts in zip(val['refs'], val['texts']):
            fid += 1
            lift_footnote(doc, footnote_part, ref, texts, f"{fid}", author=True)

    for val in case_footnotes.values():
        for ref,texts in zip(val['refs'], val['texts']):
            fid += 1
            lift_footnote(doc, footnote_part, ref, texts, f"{fid}", author=False)
    footnote_part._blob = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + etree.tostring(footnote_part.element)
    for x in doc.styles.element.xpath("//w:style[starts-with(@w:styleId,'FootnoteText-')]"):
        doc.styles.element.remove(x)
    for x in doc.styles.element.xpath("//w:style[starts-with(@w:styleId,'FootnoteReference-')]"):
        doc.styles.element.remove(x)
    return doc



def sectionizer(doc, doc_w=10080, doc_h=14400, paracols=2, internal_margin=720, external_margin=1080, big_margin=1440):
    """
        Adds section breaks for headers, footers, columns, etc.

        doc_w doc_h:
            document width and height in TWIPS
            1 TWIP = 1/20th pt. (a typographical point)
            1 inch = 1440 TWIPS
            my local grocer is about 1300 ft. in each direction, so 1 grocery trip ~= 6.5e+7 grocery TWIPs

        paracols:
            Number of columns in non-header paragraph text. There is no way to specify # of cols in a style
    """

    doc_w = Twips(doc_w)
    doc_h = Twips(doc_h)
    internal_margin = Twips(internal_margin)
    external_margin = Twips(external_margin)
    big_margin = Twips(big_margin)

    # See which rIDs pandoc gave our headers and footers. These values come
    rels = doc.part.rels
    headers_and_footers = { rels[rid].target_ref.replace('.xml', '') : rels[rid]
      for rid in rels if rels[rid].target_ref.endswith('.xml') and
      # rels lists, among other things, related xml files like header and footer.
      # target_ref property holds the file name. Check the docx word/_rels/document
      (rels[rid].target_ref.startswith('header') or rels[rid].target_ref.startswith('footer'))
    }

    body_element = doc.element.xpath('/w:document/w:body')[0]

    def section_break(destination, frontmatter=False, chapter=False, paragraph=False):
        """ Assembles the section break, appends it to the appropriate graf, properly discards the empty wrapper,
        because it gives a hoot and won't pollute. """

        # The doc itself should have an existing default section attached to body, not a paragraph
        if destination == 'doc-wide':
            sec = doc.sections[0]
        else:
            sec = doc.add_section()
            destination._element.xpath('w:pPr')[0].append(sec._sectPr)
            body_element.remove(doc.paragraphs[-1]._element)

        sec.start_type = WD_SECTION_START.CONTINUOUS if not chapter else WD_SECTION_START.ODD_PAGE
        sec.bottom_margin = internal_margin
        sec.gutter = internal_margin // 2
        sec.header_distance = external_margin
        sec.left_margin = external_margin
        sec.orientation = WD_ORIENTATION.PORTRAIT
        sec.page_height = doc_h
        sec.page_width = doc_w
        sec.right_margin = external_margin
        sec.top_margin = big_margin

        # don't need any of this stuff for just a block of paragraphs. There's defintiely a better way to differentiate
        # who does and doesn't need headers
        if not paragraph:
            sec._sectPr.add_footerReference(WD_HEADER_FOOTER_INDEX.EVEN_PAGE, headers_and_footers['footer_blank'].rId)
            sec._sectPr.add_footerReference(WD_HEADER_FOOTER_INDEX.PRIMARY, headers_and_footers['footer_blank'].rId)
            sec._sectPr.add_headerReference(WD_HEADER_FOOTER_INDEX.EVEN_PAGE, headers_and_footers['header_even'].rId)
            sec._sectPr.add_headerReference(WD_HEADER_FOOTER_INDEX.PRIMARY, headers_and_footers['header_odd'].rId)

            if frontmatter or destination == 'doc-wide':
                sec.different_first_page_header_footer = True
                sec._sectPr.add_footerReference(WD_HEADER_FOOTER_INDEX.FIRST_PAGE,
                                                        headers_and_footers['footer_title'].rId)
                sec._sectPr.add_headerReference(WD_HEADER_FOOTER_INDEX.FIRST_PAGE,
                                                        headers_and_footers['header_blank'].rId)

        # cols value and pgNumType are special cases— they're not supported by python-docx
        pgNumType_value = "lowerRoman" if frontmatter else 'decimal'
        pgNumType_query= sec._sectPr.xpath('.//w:pgNumType')
        if len(pgNumType_query) > 0:
            pgNumType_query[0].set(qn('w:fmt'), pgNumType_value)
            if frontmatter:
                pgNumType_query[0].set(qn('w:start'), "0")
            elif len(doc.sections) == 2:
                pgNumType_query[0].set(qn('w:start'), "1")
        else:
            pgNumTypeEl = OxmlElement('w:pgNumType')
            if frontmatter:
                pgNumTypeEl.set(qn('w:start'), "0")
            elif len(doc.sections) == 2:
                pgNumTypeEl.set(qn('w:start'), "1")
            pgNumTypeEl.set(qn('w:pgNumType'), pgNumType_value)
            sec._sectPr.insert_element_before(
                pgNumTypeEl, 'w:formProt', 'w:vAlign', 'w:noEndnote', 'w:titlePg',
                'w:textDirection', 'w:bidi', 'w:rtlGutter', 'w:docGrid',
                'w:printerSettings', 'w:sectPrChange'
            )

        cols_value = str(paracols) if paragraph else "1"
        cols_query = sec._sectPr.xpath('w:cols')
        if len(cols_query) > 0:
            cols_query[0].set(qn('w:num'), cols_value)
        else:
            cols_element = OxmlElement('w:cols')
            cols_element.set(qn('w:num'), cols_value)
            sec._sectPr.insert_element_before(
                cols_element, 'w:pgNumType', 'w:formProt', 'w:vAlign', 'w:noEndnote', 'w:titlePg',
                'w:textDirection', 'w:bidi', 'w:rtlGutter', 'w:docGrid',
                'w:printerSettings', 'w:sectPrChange'
            )

    # the number of body styles we use consistently is much smaller than the number of section topper styles, but the
    # values are more predictable. Body text can get unexpected style names handed down from pandoc
    topper_styles = [ 'About Page Title', 'Acknowledgements Subtitle', 'Acknowledgements Title',
                      'Node End', 'Node Start',
                      'Head Separator', 'Head End', 'Head Field Separator',
                      'Casebook Headnote', 'Casebook Headnote Title', 'Casebook Link', 'Casebook Number',
                      'Casebook Subtitle', 'Casebook Title',
                      'Chapter Headnote', 'Chapter Link', 'Chapter Number', 'Chapter Subtitle', 'Chapter Title',
                      'Section Headnote', 'Section Link', 'Section Number', 'Section Subtitle', 'Section Title',
                      'Resource Headnote', 'Resource Link', 'Resource Number', 'Resource Subtitle', 'Resource Title',
                      'Case Header',
                      'Heading 1', 'Heading 2', 'Heading 3', 'Heading 4', 'Heading 5', 'Heading 6', 'Heading 7',
                      'Heading 8', 'Heading 9',
                      'Subheading 1', 'Subheading 2', 'Subheading 3', 'Subheading 4', 'Subheading 5', 'Subheading 6',
                      'Subheading 7', 'Subheading 8', 'Subheading 9']

    section_break("doc-wide") # set the values in the section-wide sectpr

    # this is like twice as fast as navigating the xml or the docx object
    grafs = [p.style.name for p in doc.paragraphs]
    for i, p in enumerate(grafs):
        if p == 'Front Matter End':
            section_break(doc.paragraphs[i], frontmatter=True, chapter=False, paragraph=False)
        elif p == 'Node End' and (grafs[i - 1] not in topper_styles):
            section_break(doc.paragraphs[i], frontmatter=False, chapter=False, paragraph=True)
        elif p == 'Node End':
            section_break(doc.paragraphs[i], frontmatter=False, chapter=False, paragraph=False)
        elif p == 'Head End':
            if grafs[i - 1].startswith('Chapter'):
                section_break(doc.paragraphs[i-1], frontmatter=False, chapter=True, paragraph=False)
            if grafs[i + 1] == 'Case Header':
                continue
            else:
                section_break(doc.paragraphs[i], frontmatter=False, chapter=False, paragraph=False)
        elif p == 'Case Header':
            if grafs[i + 1] == 'Case Header':
                continue
            else:
                section_break(doc.paragraphs[i], frontmatter=False, chapter=False, paragraph=False)
    return doc


def handler(event, context):

    input_s3_key = event['filename']
    is_casebook = event['is_casebook']
    options = event.get('options', {})

    s3_config = {}
    if os.environ.get('USE_S3_CREDENTIALS'):
        s3_config['endpoint_url'] = os.environ['S3_ENDPOINT_URL']
        s3_config['aws_access_key_id'] = os.environ['AWS_ACCESS_KEY_ID']
        s3_config['aws_secret_access_key'] = os.environ['AWS_SECRET_ACCESS_KEY']

    with tempfile.NamedTemporaryFile(suffix='.docx') as pandoc_in:
        # get the source html
        s3 = boto3.resource('s3', **s3_config)
        s3.Bucket(os.environ['EXPORT_BUCKET']).download_fileobj(input_s3_key, pandoc_in)
        pandoc_in.seek(0)

        # convert to docx with pandoc
        with tempfile.NamedTemporaryFile(suffix='.docx') as pandoc_out:
            command = [
                'pandoc',
                '--from', 'html',
                '--to', 'docx',
                '--reference-doc', 'reference.docx',
                '--output', pandoc_out.name,
                '--quiet'
            ]
            if is_casebook:
                command.extend(['--lua-filter', 'table_of_contents.lua'])
            try:
                response = subprocess.run(command, input=pandoc_in.read(), stderr=subprocess.PIPE,
                                          stdout=subprocess.PIPE)
            except subprocess.CalledProcessError as e:
                raise Exception(f"Pandoc command failed: {e.stderr[:100]}")
            if response.stderr:
                raise Exception(f"Pandoc reported error: {response.stderr[:100]}")
            try:
                response.check_returncode()
            except subprocess.CalledProcessError as e:
                if e.returncode < 0:
                    try:
                        sig_string = str(signal.Signals(-e.returncode))
                    except ValueError:
                        sig_string = f"unknown signal {-e.returncode}"
                else:
                    sig_string = f"non-zero exit status {e.returncode}"
                ss = "Pandoc command exited with " + str(sig_string)
                pandoc_out.seek(0,0)
                raise Exception(ss)
            if not os.path.getsize(pandoc_out.name) > 0:
                raise Exception(f"Pandoc produced no output.")

            if options.get('word_footnotes', False):
                doc = Document(pandoc_out)
                promote_case_footnotes(doc)
                output = io.BytesIO()
                doc.save(output)
                output.seek(0,0)
                return output.read()

            doc = Document(pandoc_out)
            sectionizer(doc)
            output = io.BytesIO()
            doc.save(output)
            output.seek(0, 0)
            return output.read()
