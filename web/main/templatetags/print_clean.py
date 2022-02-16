import re
from lxml.html import tostring
from lxml.html.clean import Cleaner

from django import template
from django.utils.safestring import mark_safe
from main.utils import parse_html_fragment

register = template.Library()

cleaner = Cleaner(style=True, scripts=True, links=True,
                  page_structure=True, safe_attrs_only=True,
                  remove_unknown_tags=True, kill_tags=['style', 'script', 'link', 'meta'])
td = re.compile(r'(text-decoration|font-weight|font-style): ?(?!none|mormal)([^";>]+)')


@register.filter
def print_clean(html_content):
    user_content = parse_html_fragment(html_content)
    for c_el in user_content.iter():
        # if c.tag == 'div': # class="toc-entry" data-depth="3" data-idx="233" data-title=

        if 'case-header' in c_el.get('class', ''):
            c_el.set('data-custom-style', 'case-header')
        while len(c_el.attrib) > 0:
            c_el.attrib.pop(c_el.attrib.keys()[0])

        if (c_el.text_content().isspace() or c_el.text_content == '') and (
                c_el.text is None or c_el.text.isspace() or c_el.text == '') and (
                not c_el.tail or c_el.tail.isspace() or c_el.tail == '') and \
                not c_el.get('data-title', False)  and c_el.get('class', None) != 'table-of-contents' and \
                c_el.tag not in ['table', 'td', 'tr', 'tbody', 'thead', 'img', 'fig'] and c_el.getparent() is not None:
            c_el.drop_tag()
        if c_el.tag == 'span':
            if c_el.get('data-custom-style', None):
                continue
            elif td.findall(c_el.get('style', '')):
                c_el.set('data-preserve-style', '; '.join([f"{s[0]}: {s[1]}" for s in td.findall(c_el.get('style'))]))
                # print(td.findall(c.attrib.get('style', '')))
                # print(td.findall(c.attrib.get('style', '')))
                c_el.attrib.pop('style')
                if c_el.get('class', None):
                    c_el.attrib.pop('class')
            else:
                if c_el.getparent() is not None:
                    c_el.drop_tag()
                continue

    return mark_safe(tostring(user_content, encoding='unicode'))
