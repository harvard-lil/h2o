import bleach
from copy import deepcopy
from datetime import datetime, date
import html as   python_html
from lxml import etree, html
import mimetypes
import re
from urllib.parse import quote

from django.http import HttpResponse
from django.conf import settings


class CapapiCommunicationException(Exception):
    pass


def sanitize(html):
    """
    TODO: read up on this sanitization library
    """
    return bleach.clean(html, tags=['p', 'br', 'span', *bleach.sanitizer.ALLOWED_TAGS])


def show_debug_toolbar(request):
    """
        Whether to show the Django debug toolbar.
    """
    return bool(settings.DEBUG)


def parse_cap_decision_date(decision_date_text):
    """
        Parse a CAP decision date string into a datetime object.

        >>> assert parse_cap_decision_date('2019-10-27') == date(2019, 10, 27)
        >>> assert parse_cap_decision_date('2019-10') == date(2019, 10, 1)
        >>> assert parse_cap_decision_date('2019') == date(2019, 1, 1)
        >>> assert parse_cap_decision_date('2019-02-29') == date(2019, 2, 1)  # non-existent day of month
        >>> assert parse_cap_decision_date('not a date') is None
    """
    try:
        try:
            return datetime.strptime(decision_date_text, '%Y-%m-%d').date()
        except ValueError as e:

            # if court used an invalid day of month (typically Feb. 29), strip day from date
            if e.args[0] == 'day is out of range for month':
                decision_date_text = decision_date_text.rsplit('-', 1)[0]

            try:
                return datetime.strptime(decision_date_text, '%Y-%m').date()
            except ValueError:
                return datetime.strptime(decision_date_text, '%Y').date()
    except Exception:
        # if for some reason we can't parse the date, just store None
        return None


def looks_like_citation(s):
    """
        Return True if string s looks like a case citation (starts and stops with digits).

        >>> all(looks_like_citation(s) for s in [
        ...     "123 Mass. 456",
        ...     "123-mass-456",
        ...     "123 anything else here 456",
        ... ])
        True
        >>> not any(looks_like_citation(s) for s in [
        ...     "123Mass.456",
        ...     "123 Mass.",
        ... ])
        True
    """
    return bool(re.match(r'\d+(\s+|-).*(\s+|-)\d+$', s))


def clone_model_instance(instance, **kwargs):
    clone = deepcopy(instance)
    clone.id = clone.pk = clone.created_at = None
    for k, v in kwargs.items():
        setattr(clone, k, v)
    return clone


def fix_before_deploy(message):
    """ Use this to document questions that should be answered before a given line of code is allowed to run on production. """
    if not settings.NOT_ON_PRODUCTION:
        raise ValueError(message)


def fix_after_rails(message):
    """ Use this to document actions that should be taken after the migration to Python is complete. """
    pass


def re_split_offsets(pattern, s):
    """
        Split a string by regular expression, and return the substrings, the offsets for each separator, and the text
        of each separator. This is useful for setting up annotation test templates. Example:

        >>> assert re_split_offsets(r'[A-Z]', "AaaBbbCccDdd") == (
        ...     ["", "aa", "bb", "cc", "dd"],
        ...     [0, 2, 4, 6],
        ...     ["A", "B", "C", "D"],
        ... )
    """
    parts = re.split(r'(%s)' % pattern, s)
    strs = [parts[i] for i in range(0, len(parts), 2)]
    split_strs = [parts[i] for i in range(1, len(parts), 2)]
    split_offsets = [sum(len(s) for s in strs[:i+1]) for i in range(len(strs)-1)]
    return strs, split_offsets, split_strs


def parse_html_fragment(html_str):
    """
        Parse an html fragment (one or more tags with optional surrounding text) into an lxml tree
        wrapped in a parent <div>.
    """
    # lxml's fragment_fromstring() throws away whitespace that comes at the start of the string if followed by
    # a tag. Avoid this edgecase by stripping leading whitespace and re-appending to our output:
    initial_spaces = re.match(r'\s+', html_str)
    if initial_spaces:
        initial_spaces = initial_spaces.group(0)
        html_str = html_str[len(initial_spaces):]
    else:
        initial_spaces = ''

    el = html.fragment_fromstring(html_str, create_parent=True)
    if initial_spaces:
        el.text = initial_spaces + (el.text or '')

    return el

fix_after_rails("this is redundant of the BLOCK_LEVEL_ELEMENTS javascript array; one could feed the other once we move the asset pipeline over")
block_level_elements = {
    'address', 'article', 'aside', 'blockquote', 'details', 'dialog', 'dd', 'div', 'dl', 'dt', 'fieldset', 'figcaption',
    'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'li', 'main', 'nav', 'ol',
    'p', 'pre', 'section', 'table', 'ul'
}
void_elements = {
    'base', 'command', 'event-source', 'link', 'meta', 'hr', 'br', 'img', 'embed', 'param', 'area', 'col', 'input',
    'source', 'track'
}


def remove_empty_tags(tree, ignore_tags=void_elements):
    """
        Remove empty child elements from an lxml Element, except for any listed in the ignore_tags set. Example:
            >>> tree = etree.XML('<p>asfd<a><b>asdf<c/>asdf</b></a>asdf<d></d></p>')
            >>> remove_empty_tags(tree)
            >>> etree.tostring(tree)
            b'<p>asfd<a><b>asdfasdf</b></a>asdf</p>'
            >>> tree = etree.XML('<p><a><b><c></c></b></a></p>')
            >>> remove_empty_tags(tree, {'a'})
            >>> etree.tostring(tree)
            b'<p><a/></p>'
    """
    for el in tree.iterdescendants():
        while True:
            if el.tag in ignore_tags or el.text or len(el):
                break
            parent = el.getparent()
            if el.tail:
                prev = el.getprevious()
                if prev is None:
                    parent.text = (parent.text or '') + el.tail
                else:
                    prev.tail = (prev.tail or '') + el.tail
            parent.remove(el)
            if parent == tree:
                break
            el = parent


def inner_html(tree):
    """ Return inner HTML of lxml element """
    return (python_html.escape(tree.text) if tree.text else '') + \
        ''.join([html.tostring(child, encoding=str) for child in tree.iterchildren()])


class StringFileResponse(HttpResponse):
    """
        A response that sets Content-Type and Content-Disposition like Django's FileResponse, but takes a string instead
        of a filelike object. This is needed because uwsgi can't handle BytesIO objects --
        see https://github.com/unbit/uwsgi/issues/1126

        Logic based on django.http.response.FileResponse.set_headers.
    """
    def __init__(self, *args, as_attachment=False, filename='', **kwargs):
        super().__init__(*args, **kwargs)

        # set Content-Type
        if self.get('Content-Type', '').startswith('text/html'):
            if filename:
                content_type, encoding = mimetypes.guess_type(filename)
                # Encoding isn't set to prevent browsers from automatically
                # uncompressing files.
                encoding_map = {
                    'bzip2': 'application/x-bzip',
                    'gzip': 'application/gzip',
                    'xz': 'application/x-xz',
                }
                content_type = encoding_map.get(encoding, content_type)
                self['Content-Type'] = content_type or 'application/octet-stream'
            else:
                self['Content-Type'] = 'application/octet-stream'

        # set Content-Disposition
        if filename:
            disposition = 'attachment' if as_attachment else 'inline'
            try:
                filename.encode('ascii')
                file_expr = 'filename="{}"'.format(filename)
            except UnicodeEncodeError:
                file_expr = "filename*=utf-8''{}".format(quote(filename))
            self['Content-Disposition'] = '{}; {}'.format(disposition, file_expr)
        elif as_attachment:
            self['Content-Disposition'] = 'attachment'