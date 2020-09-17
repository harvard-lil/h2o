from copy import deepcopy
from datetime import datetime, date
import difflib
import html as   python_html
from lxml import etree, html
import mimetypes
from pyquery import PyQuery
import re
from requests import request
from urllib.parse import quote, unquote

from django.contrib.auth.tokens import default_token_generator
from django.http import HttpResponse
from django.conf import settings
from django.core.mail import send_mail
from django.template import Context, RequestContext, engines
from django.urls import reverse
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

from .sanitize import sanitize


class CapapiCommunicationException(Exception):
    pass


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

def looks_like_case_law_link(s):
    return bool(re.match(r'^https?://cite\.case\.law(/[/0-9a-zA-Z_-]*)$', s))


def clone_model_instance(instance, **kwargs):
    clone = deepcopy(instance)
    clone.id = clone.pk = clone.created_at = None
    for k, v in kwargs.items():
        setattr(clone, k, v)
    return clone


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


def normalize_newlines(html_string):
    r"""
        >>> assert normalize_newlines('<p>Hi\r</p>\r\n') == '<p>Hi\n</p>\n'

        We're doing this for a number of reasons.

        1) Consistent line endings make it easier to detect if a string has meaningfully changed.

        2) In our experience, consistent line endings help ensure annotation offsets are handled
        accurately across libraries and languages. Since Django's admin forms POST \n, but the
        WYSIWYG CKEditor uses \r\n, it's easy to end up with a mix of both in the DB... and newlines
        reportedly can be handled differently by different browsers.

        3) Further, the sanitization library "bleach" converts \r to \n, doubling the newlines,
        and forcing annotation offsets to require updating:
        >>> assert sanitize('<p>hello\r</p>\r\n\r\n<p>there</p>') == '<p>hello\n</p>\n\n<p>there</p>'
    """
    return html_string.replace("\r\n", "\n").replace("\r", "\n")


def strip_trailing_block_level_whitespace(html_string):
    r"""
        >>> assert strip_trailing_block_level_whitespace("<p>foo</p>  \r\n \n <p>bar</p>  ") == "<p>foo</p><p>bar</p>"

        We're doing this because the whitespace is being handled by our annotation-placing javascript
        and our css in an undesirable way, resulting in a change to the rendered paragraph numbers
        and visual anomalies, when the whitespace is within an annotated range.

        fix_after_rails("We'd prefer to take a different approach in the JS and the CSS, instead
        of removing the whitespace, but leave that rewrite for another time.")
    """
    tree = parse_html_fragment(html_string)
    for el in tree.iterdescendants():
        if el.tag in block_level_elements and el.tail and re.match(r'\s+$', el.tail):
            el.tail = ''
    return inner_html(tree)


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
# via https://developer.mozilla.org/en-US/docs/Glossary/empty_element
void_elements = {
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'keygen', 'link', 'meta', 'param', 'source', 'track', 'wbr'
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


def elements_equal(e1, e2, ignore={}, ignore_trailing_whitespace=False, tidy_style_attrs=False, exc_class=ValueError):
    """
        Recursively compare two lxml Elements.
        Raise an exception (by default ValueError) if not identical.
        Optionally, ignore trailing whitespace after block elements.
        Optionally, munge "style" attributes for easier comparison.
    """
    if e1.tag != e2.tag:
        raise exc_class("e1.tag != e2.tag (%s != %s)" % (e1.tag, e2.tag))
    if e1.text != e2.text:
        diff = '\n'.join(difflib.ndiff([e1.text or ''], [e2.text or '']))
        raise exc_class("e1.text != e2.text:\n%s" % diff)
    if e1.tail != e2.tail:
        exc = exc_class("e1.tail != e2.tail (%s != %s)" % (e1.tail, e2.tail))
        if ignore_trailing_whitespace:
            if (e1.tail or '').strip() or (e2.tail or '').strip():
                raise exc
        else:
            raise exc
    ignore_attrs = ignore.get('attrs', set()) | ignore.get('tag_attrs', {}).get(e1.tag.rsplit('}', 1)[-1], set())
    e1_attrib = {k:v for k,v in e1.attrib.items() if k not in ignore_attrs}
    e2_attrib = {k:v for k,v in e2.attrib.items() if k not in ignore_attrs}
    if tidy_style_attrs and e1_attrib.get('style'):
        # allow easy comparison of sanitized style tags by removing all spaces and final semicolon
        e1_attrib['style'] = e1_attrib['style'].replace(' ', '').rstrip(';')
        e2_attrib['style'] = e2_attrib['style'].replace(' ', '').rstrip(';')
    if e1_attrib != e2_attrib:
        diff = "\n".join(difflib.Differ().compare(["%s: %s" % i for i in sorted(e1_attrib.items())], ["%s: %s" % i for i in sorted(e2_attrib.items())]))
        raise exc_class("e1.attrib != e2.attrib:\n%s" % diff)
    s1 = [i for i in e1 if i.tag.rsplit('}', 1)[-1] not in ignore.get('tags', ())]
    s2 = [i for i in e2 if i.tag.rsplit('}', 1)[-1] not in ignore.get('tags', ())]
    if len(s1) != len(s2):
        diff = "\n".join(difflib.Differ().compare([s.tag for s in s1], [s.tag for s in s2]))
        raise exc_class("e1 children != e2 children:\n%s" % diff)
    for c1, c2 in zip(s1, s2):
        elements_equal(c1, c2, ignore, ignore_trailing_whitespace, tidy_style_attrs, exc_class)

    # If you've gotten this far without an exception, the elements are equal
    return True


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


def get_ip_address(request):
    """
        Get user's IP address from request object.
        Use Cloudflare CF-Connecting-IP header, falling back to REMOTE_ADDR for dev.
    """
    return request.META.get('HTTP_CF_CONNECTING_IP', request.META.get('REMOTE_ADDR'))


def render_plaintext_template_to_string(template, context, request=None):
    """
        Render a template to string WITHOUT Django's autoescaping, for
        use with non-HTML templates. Do not use with HTML templates!
    """
    # load the django template engine directly, so that we can
    # pass in a Context/RequestContext object with autoescape=False
    # https://docs.djangoproject.com/en/1.11/topics/templates/#django.template.loader.engines
    #
    # (though render and render_to_string take a "context" kwarg of type dict,
    #  that dict cannot be used to configure autoescape, but only to pass keys/values to the template)
    engine = engines['django'].engine
    if request:
        ctx = RequestContext(request, context, autoescape=False)
    else:
        ctx = Context(context, autoescape=False)
    return engine.get_template(template).render(ctx)


def send_template_email(subject, template, context, from_address, to_addresses):
    context.update({s: getattr(settings, s) for s in settings.TEMPLATE_VISIBLE_SETTINGS})
    email_text = render_plaintext_template_to_string(template, context)
    success_count = send_mail(
        subject,
        email_text,
        from_address,
        to_addresses,
        fail_silently=False
    )
    return success_count


def send_verification_email(request, user):
    # Send verify-email-address email.
    # This uses the forgot-password flow; logic is borrowed from auth_forms.PasswordResetForm.save()
    verify_link = request.build_absolute_uri(reverse('password_reset_confirm', args=[
        urlsafe_base64_encode(force_bytes(user.pk)),
        default_token_generator.make_token(user),
    ]))
    message = "To activate your account, please click the link below or copy it to your web browser.  " \
        "You will need to create a new password.\n\n%s" % verify_link
    send_mail(
        "An H2O account has been created for you",
        message,
        settings.DEFAULT_FROM_EMAIL,
        [user.email_address],
    )


def send_invitation_email(request, receiving_user, casebook):
    # A new user has been invited to collaborate on a casebook
    # Send an email that looks like a verification email, but explains the invitation
    # They need to set their initial password, so this borrows from send_verification_email above
    verify_link = request.build_absolute_uri(reverse('password_reset_confirm', args=[
        urlsafe_base64_encode(force_bytes(receiving_user.pk)),
        default_token_generator.make_token(receiving_user),
    ]))
    inviting_user = request.user
    message = """You have been invited by {} to collaborate on a casebook titled {}.

You can set up your account by choosing a password at {}.

Access this casebook directly at {} or visit your dashboard at {} to see all of your casebooks.

To learn more, please visit our help guide at https://about.opencasebook.org/. If you have questions, you can reach us at info@opencasebook.org.


The H2O-OpenCasebook team
Harvard Law School Library""".format(inviting_user.email_address, casebook.title, verify_link, request.build_absolute_uri(casebook.get_absolute_url()), request.build_absolute_uri("/"))
    send_mail(
        "{} has invited you to collaborate on a casebook".format(inviting_user.attribution),
        message,
        settings.DEFAULT_FROM_EMAIL,
        [receiving_user.email_address],
    )


def send_collaboration_email(request, receiving_user, casebook):
    # For already existing users, send a notice that they've been invited to collaborate
    inviting_user = request.user
    message = """You have been invited by {} to collaborate on a casebook titled {}.

Access this casebook directly at {} or visit your dashboard at {} to see all of your casebooks.

To learn more, please visit our help guide at https://about.opencasebook.org/. If you have questions, you can reach us at info@opencasebook.org.

The H2O-OpenCasebook team
Harvard Law School Library""".format(inviting_user.email_address, casebook.title, request.build_absolute_uri(casebook.get_absolute_url()), request.build_absolute_uri("/"))
    send_mail(
        "{} has invited you to collaborate on a casebook.".format(inviting_user.attribution),
        message,
        settings.DEFAULT_FROM_EMAIL,
        [receiving_user.email_address],
    )


def get_link_title(url):
    file_name_re = re.compile('/([^/]*)(?:[.].{1,4})$')
    last_slug_re = re.compile('/([^/]*)/$')
    file_name = file_name_re.search(url)
    default_title = url
    last_slug = last_slug_re.search(url)
    if file_name and file_name.groups()[0]:
        default_title = unquote(file_name.groups()[0])
    elif last_slug and last_slug.groups()[0]:
        default_title = unquote(last_slug.groups()[0])
    resp = request('get',url)
    if not resp.ok:
        return default_title
    body = PyQuery(resp.content)
    if not body:
        return default_title
    title = body.find('title')
    if not title:
        return default_title
    return title[0].text
