"""Regression checks for Word export postprocessing."""
import unittest
from io import BytesIO
from zipfile import ZipFile

from docx import Document
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls
from lxml import etree

from app import promote_case_footnotes


class CaseFootnoteTests(unittest.TestCase):
    def test_footnote_boundaries(self):
        for boundary in ('bookmarkStart', 'bookmarkEnd', 'sectPr', None):
            for continuation in (False, True):
                with self.subTest(boundary=boundary, continuation=continuation):
                    doc = Document('reference.docx')
                    body = doc.element.body
                    for child in list(body):
                        body.remove(child)
                    body.append(parse_xml(f'''<w:p {nsdecls('w')}>
                        <w:r><w:rPr><w:rStyle w:val="CaseFootnoteReference-1"/></w:rPr><w:t>1</w:t></w:r>
                        </w:p>'''))
                    body.append(parse_xml(f'''<w:p {nsdecls('w')}>
                        <w:pPr><w:pStyle w:val="CaseFootnoteText-1"/></w:pPr>
                        <w:hyperlink w:anchor="note1"><w:r><w:rPr><w:rStyle w:val="CaseFootnoteRef"/></w:rPr><w:t>1</w:t></w:r></w:hyperlink>
                        <w:r><w:t>First paragraph.</w:t></w:r></w:p>'''))
                    if continuation:
                        body.append(parse_xml(f'''<w:p {nsdecls('w')}>
                            <w:pPr><w:pStyle w:val="CaseFootnoteText-1"/></w:pPr>
                            <w:r><w:t>Continuation.</w:t></w:r></w:p>'''))
                    if boundary:
                        body.append(parse_xml(f'<w:{boundary} {nsdecls("w")} w:id="100"/>'))
                    promote_case_footnotes(doc, docx_sections=True)
                    output = BytesIO()
                    doc.save(output)
                    with ZipFile(output) as archive:
                        notes = etree.fromstring(archive.read('word/footnotes.xml'))
                        ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
                        text = notes.xpath('//w:footnote[@w:id="2"]//w:t/text()', namespaces=ns)
                        self.assertIn('First paragraph.', text)
                        self.assertEqual('Continuation.' in text, continuation)
                        self.assertEqual(len(doc.element.xpath('//w:footnoteReference')), 1)
                        if boundary:
                            self.assertEqual(etree.QName(body[-1]).localname, boundary)


if __name__ == '__main__':
    unittest.main()
