import boto3
import io
import os
import signal
import subprocess
import tempfile
from docx import Document
from docx.oxml import OxmlElement, parse_xml
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
                print(ss)
                pandoc_out.seek(0,0)
                print(response.stderr)
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
            return pandoc_out.read()
