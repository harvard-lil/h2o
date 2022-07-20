import base64
import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError as BotoClientError
from copy import deepcopy
from datetime import datetime, date
import difflib
import html as python_html
import json
from lxml import etree, html
import mimetypes
from PIL import Image, UnidentifiedImageError
from pyquery import PyQuery
import re
import requests
import tempfile
from urllib.parse import quote, unquote


from django.contrib.auth.tokens import default_token_generator
from django.http import HttpResponse
from django.conf import settings
from django.core.mail import send_mail
from django.template import Context, RequestContext, engines
from django.urls import reverse
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode
from django.db.models import Exists, OuterRef, QuerySet

from .sanitize import sanitize
from .storages import get_s3_storage

import logging

logger = logging.getLogger(__name__)


class APICommunicationError(Exception):
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
            return datetime.strptime(decision_date_text, "%Y-%m-%d").date()
        except ValueError as e:

            # if court used an invalid day of month (typically Feb. 29), strip day from date
            if e.args[0] == "day is out of range for month":
                decision_date_text = decision_date_text.rsplit("-", 1)[0]

            try:
                return datetime.strptime(decision_date_text, "%Y-%m").date()
            except ValueError:
                return datetime.strptime(decision_date_text, "%Y").date()
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
    return bool(re.match(r"\d+(\s+|-).*(\s+|-)\d+$", s))


def looks_like_case_law_link(s):
    return bool(re.match(r"^https?://cite\.case\.law(/[/0-9a-zA-Z_-]*)$", s))


def clone_model_instance(instance, **kwargs):
    clone = deepcopy(instance)
    clone.id = clone.pk = clone.created_at = None
    for k, v in kwargs.items():
        setattr(clone, k, v)
    return clone


def fix_after_rails(message):
    """Use this to document actions that should be taken after the migration to Python is complete."""
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
    parts = re.split(f"({pattern})", s)
    strs = [parts[i] for i in range(0, len(parts), 2)]
    split_strs = [parts[i] for i in range(1, len(parts), 2)]
    split_offsets = [sum(len(s) for s in strs[: i + 1]) for i in range(len(strs) - 1)]
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
        if el.tag in block_level_elements and el.tail and re.match(r"\s+$", el.tail):
            el.tail = ""
    return inner_html(tree)


def parse_html_fragment(html_str):
    """
    Parse an html fragment (one or more tags with optional surrounding text) into an lxml tree
    wrapped in a parent <div>.
    """
    # lxml's fragment_fromstring() throws away whitespace that comes at the start of the string if followed by
    # a tag. Avoid this edgecase by stripping leading whitespace and re-appending to our output:
    initial_spaces = re.match(r"\s+", html_str)
    if initial_spaces:
        initial_spaces = initial_spaces.group(0)
        html_str = html_str[len(initial_spaces) :]
    else:
        initial_spaces = ""

    # It's here. This next line is the problem.
    el = html.fragment_fromstring(html_str, create_parent=True)

    if initial_spaces:
        el.text = initial_spaces + (el.text or "")

    return el


def format_footnotes_for_export(html_str):
    """
    Footnotes are stored in TextBlocks as
    `<span class="footnote footnote-ref" data-custom-style="Footnote Reference" id="footnote-${data.id}-ref">${data.mark}</span>`
    `<div class="footnote footnote-body" id="footnote-${data.id}"><p><span class="footnote-label" contenteditable="false">${data.mark}</span>${data.footnote}</p></div>`
    """
    if not html_str:
        return html_str
    pq = PyQuery(html_str)
    pq(".footnote-label").append(". ")
    return pq.outer_html()


fix_after_rails(
    "this is redundant of the BLOCK_LEVEL_ELEMENTS javascript array; one could feed the other once we move the asset pipeline over"
)
block_level_elements = {
    "address",
    "article",
    "aside",
    "blockquote",
    "details",
    "dialog",
    "dd",
    "div",
    "dl",
    "dt",
    "fieldset",
    "figcaption",
    "figure",
    "footer",
    "form",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "header",
    "hgroup",
    "hr",
    "li",
    "main",
    "nav",
    "ol",
    "p",
    "pre",
    "section",
    "table",
    "ul",
}
# via https://developer.mozilla.org/en-US/docs/Glossary/empty_element
void_elements = {
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
}


def prefix_ids_hrefs(html_str, prefix):
    if not html_str:
        return html_str

    def prefix_id(_, el):
        original_id = el.attrib["id"]
        el.attrib["id"] = f"{prefix}-{original_id}"

    def prefix_href(_, el):

        original_target = el.attrib["href"][1:]
        el.attrib["href"] = f"#{prefix}-{original_target}"

    pq = PyQuery(html_str)
    pq("[id]").each(prefix_id)
    pq("[href^='#']").each(prefix_href)
    return pq.outer_html()


def rich_text_export(html_str, request=None, id_prefix=""):
    if not (html_str and request and id_prefix):
        return html_str
    pq = PyQuery(html_str)

    # Footnote labels have an :after css pseudo element with '.' content
    # To prevent editing of the label in a way that will be lost
    pq(".footnote-label").append("  ")

    # IDs that unique within a document may not be unique within multiple documents
    # so we add a prefix
    def prefix_id(_, el):
        original_id = el.attrib["id"]
        el.attrib["id"] = f"{id_prefix}-{original_id}"

    def prefix_href(_, el):
        original_target = el.attrib["href"][1:]
        el.attrib["href"] = f"#{id_prefix}-{original_target}"

    pq("[id]").each(prefix_id)
    pq("[href^='#']").each(prefix_href)

    def remove_disallowed_images(el):
        src = el.attrib.get("src", "") or ""
        if src and not (
            src.startswith(f"http://{request.get_host()}")
            or src.startswith(f"https://{request.get_host()}")
        ):
            logger.info(f"Removing disallowed image src: {src}")
            el.getparent().remove(el)

    for el in pq("img"):
        remove_disallowed_images(el)

    # Add Doc styling wrappers to images
    def replace_in_parent(style, el):
        original_html = el.parent().html(method="html")
        src = el.outer_html()
        replacement = f"</p><div data-custom-style='{style}'>{el.outer_html()}</div><p>"
        el.parent().html(original_html.replace(src, replacement))

    def attach_id_to_style(el):
        el.attrib["data-custom-style"] += f"-{id_prefix}"

    for el in pq("img.image-center-large").items():
        replace_in_parent("Image Centered Large", el)
    for el in pq("img.image-center-medium").items():
        replace_in_parent("Image Centered Medium", el)
    for el in pq("img.image-left-medium").items():
        replace_in_parent("Image Left Medium", el)
    for el in pq("img.image-right-medium").items():
        replace_in_parent("Image Right Medium", el)
    for el in pq("[data-custom-style='Footnote Reference']"):
        attach_id_to_style(el)
    for el in pq("[data-custom-style='Footnote Text']"):
        attach_id_to_style(el)

    # Insert a non-breaking space if the paragraph after an image is empty
    # to prevent it from potentially overlapping with a following image
    pq("div[data-custom-style]+p:empty").text(" \xa0 ")

    return pq.outer_html()


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
                    parent.text = (parent.text or "") + el.tail
                else:
                    prev.tail = (prev.tail or "") + el.tail
            parent.remove(el)
            if parent == tree:
                break
            el = parent


def inner_html(tree):
    """Return inner HTML of lxml element"""
    return (python_html.escape(tree.text) if tree.text else "") + "".join(
        [html.tostring(child, encoding=str) for child in tree.iterchildren()]
    )


def elements_equal(
    e1,
    e2,
    ignore={},
    ignore_trailing_whitespace=False,
    tidy_style_attrs=False,
    exc_class=ValueError,
):
    """
    Recursively compare two lxml Elements.
    Raise an exception (by default ValueError) if not identical.
    Optionally, ignore trailing whitespace after block elements.
    Optionally, munge "style" attributes for easier comparison.
    """
    if e1.tag != e2.tag:
        raise exc_class(f"e1.tag != e2.tag ({e1.tag} != {e2.tag})")
    e1t = (e1.text and e1.text.replace("\n", "").strip()) or ""
    e2t = (e2.text and e2.text.replace("\n", "").strip()) or ""
    if e1t != e2t:
        diff = "\n".join(difflib.ndiff([e1.text or ""], [e2.text or ""]))
        raise exc_class(f"e1.text != e2.text:\n{diff}")
    e1tail = (e1.tail or "").strip()
    e2tail = (e2.tail or "").strip()
    if e1tail != e2tail:
        exc = exc_class(f"e1.tail != e2.tail ({e1.tail} != {e2.tail})")
        if ignore_trailing_whitespace:
            if (e1.tail or "").strip() or (e2.tail or "").strip():
                raise exc
        else:
            raise exc
    ignore_attrs = ignore.get("attrs", set()) | ignore.get("tag_attrs", {}).get(
        e1.tag.rsplit("}", 1)[-1], set()
    )
    e1_attrib = {k: v for k, v in e1.attrib.items() if k not in ignore_attrs}
    e2_attrib = {k: v for k, v in e2.attrib.items() if k not in ignore_attrs}
    if tidy_style_attrs and e1_attrib.get("style"):
        # allow easy comparison of sanitized style tags by removing all spaces and final semicolon
        e1_attrib["style"] = e1_attrib["style"].replace(" ", "").rstrip(";")
        e2_attrib["style"] = e2_attrib["style"].replace(" ", "").rstrip(";")
    if e1_attrib != e2_attrib:
        diff = "\n".join(
            difflib.Differ().compare(
                [f"{i}: {i}" % i for i in sorted(e1_attrib.items())],
                [f"{i}: {i}" for i in sorted(e2_attrib.items())],
            )
        )
        raise exc_class(f"e1.attrib != e2.attrib:\n{diff}")
    s1 = [i for i in e1 if i.tag.rsplit("}", 1)[-1] not in ignore.get("tags", ())]
    s2 = [i for i in e2 if i.tag.rsplit("}", 1)[-1] not in ignore.get("tags", ())]
    if len(s1) != len(s2):
        diff = "\n".join(difflib.Differ().compare([s.tag for s in s1], [s.tag for s in s2]))
        raise exc_class(f"e1 children != e2 children:\n{diff}")
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

    def __init__(
        self, *args, as_attachment=False, filename="", response_flag_cookie=False, **kwargs
    ):
        super().__init__(*args, **kwargs)

        # set Content-Type
        if self.get("Content-Type", "").startswith("text/html"):
            if filename:
                content_type, encoding = mimetypes.guess_type(filename)
                # Encoding isn't set to prevent browsers from automatically
                # uncompressing files.
                encoding_map = {
                    "bzip2": "application/x-bzip",
                    "gzip": "application/gzip",
                    "xz": "application/x-xz",
                }
                content_type = encoding_map.get(encoding, content_type)
                self["Content-Type"] = content_type or "application/octet-stream"
            else:
                self["Content-Type"] = "application/octet-stream"

        # set Content-Disposition
        if filename:
            disposition = "attachment" if as_attachment else "inline"
            try:
                filename.encode("ascii")
                file_expr = f'filename="{filename}"'
            except UnicodeEncodeError:
                file_expr = f"filename*=utf-8''{quote(filename)}"
            self["Content-Disposition"] = f"{disposition}; {file_expr}"
        elif as_attachment:
            self["Content-Disposition"] = "attachment"

        if response_flag_cookie:
            self.set_cookie("response_flag_cookie", value="response_flag_cookie", max_age=5)


def get_ip_address(request):
    """
    Get user's IP address from request object.
    Use Cloudflare CF-Connecting-IP header, falling back to REMOTE_ADDR for dev.
    """
    return request.META.get("HTTP_CF_CONNECTING_IP", request.META.get("REMOTE_ADDR"))


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
    engine = engines["django"].engine
    if request:
        ctx = RequestContext(request, context, autoescape=False)
    else:
        ctx = Context(context, autoescape=False)
    return engine.get_template(template).render(ctx)


def send_template_email(subject, template, context, from_address, to_addresses):
    context.update({s: getattr(settings, s) for s in settings.TEMPLATE_VISIBLE_SETTINGS})
    email_text = render_plaintext_template_to_string(template, context)
    success_count = send_mail(subject, email_text, from_address, to_addresses, fail_silently=False)
    return success_count


def send_verification_email(request, user):
    # Send verify-email-address email.
    # This uses the forgot-password flow; logic is borrowed from auth_forms.PasswordResetForm.save()
    verify_link = request.build_absolute_uri(
        reverse(
            "password_reset_confirm",
            args=[
                urlsafe_base64_encode(force_bytes(user.pk)),
                default_token_generator.make_token(user),
            ],
        )
    )
    message = (
        "To activate your account, please click the link below or copy it to your web browser.  "
        f"You will need to create a new password.\n\n{verify_link}"
    )
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
    verify_link = request.build_absolute_uri(
        reverse(
            "password_reset_confirm",
            args=[
                urlsafe_base64_encode(force_bytes(receiving_user.pk)),
                default_token_generator.make_token(receiving_user),
            ],
        )
    )
    inviting_user = request.user
    message = f"""You have been invited by {inviting_user.email_address} to collaborate on a casebook titled {casebook.title}.

You can set up your account by choosing a password at {verify_link}.

Access this casebook directly at {request.build_absolute_uri(casebook.get_absolute_url())} or visit your dashboard at {request.build_absolute_uri("/")} to see all of your casebooks.

To learn more, please visit our help guide at https://about.opencasebook.org/. If you have questions, you can reach us at info@opencasebook.org.


The H2O open casebook team
Harvard Law School Library"""
    send_mail(
        f"{inviting_user.attribution} has invited you to collaborate on a casebook",
        message,
        settings.DEFAULT_FROM_EMAIL,
        [receiving_user.email_address],
    )


def send_collaboration_email(request, receiving_user, casebook):
    # For already existing users, send a notice that they've been invited to collaborate
    inviting_user = request.user
    message = f"""You have been invited by {inviting_user.email_address} to collaborate on a casebook titled {casebook.title}.

Access this casebook directly at { request.build_absolute_uri(casebook.get_absolute_url())} or visit your dashboard at {request.build_absolute_uri("/")} to see all of your casebooks.

To learn more, please visit our help guide at https://about.opencasebook.org/. If you have questions, you can reach us at info@opencasebook.org.

The H2O open casebook team
Harvard Law School Library"""
    send_mail(
        f"{inviting_user.attribution} has invited you to collaborate on a casebook.",
        message,
        settings.DEFAULT_FROM_EMAIL,
        [receiving_user.email_address],
    )


def get_link_title(url):
    file_name_re = re.compile("/([^/]*)(?:[.].{1,4})$")
    last_slug_re = re.compile("/([^/]*)/$")
    file_name = file_name_re.search(url)
    default_title = url
    last_slug = last_slug_re.search(url)
    if file_name and file_name.groups()[0]:
        default_title = unquote(file_name.groups()[0])
    elif last_slug and last_slug.groups()[0]:
        default_title = unquote(last_slug.groups()[0])
    resp = None
    try:
        resp = requests.get(url, verify=False)
    except Exception:
        return default_title
    if not resp or not resp.ok:
        return default_title
    body = PyQuery(resp.content)
    if not body:
        return default_title
    title = body.find("title")
    if not title:
        return default_title
    return title[0].text


class LambdaExportTooLarge(RuntimeError):
    pass


def export_via_aws_lambda(obj, html, file_type, docx_footnotes=None, docx_sections=False):
    export_settings = settings.AWS_LAMBDA_EXPORT_SETTINGS
    export_type = obj.__class__.__name__
    log_line_prefix = f"Exporting {export_type} {obj.id}"

    logger.info(f"{log_line_prefix}: uploading source")
    storage = get_s3_storage(
        bucket_name=export_settings["bucket_name"],
        config=dict(
            access_key=export_settings["access_key"],
            secret_key=export_settings["secret_key"],
            **(
                {"endpoint_url": export_settings["endpoint_url"]}
                if export_settings.get("endpoint_url")
                else {}
            ),
        ),
    )
    with tempfile.NamedTemporaryFile(suffix=".html") as inputfile:
        # temporarily save the html source to s3, where the lambda can access it
        filename = f"{export_type.lower()}-{obj.id}-{inputfile.name.split('/')[-1]}"
        inputfile.write(bytes(html, "utf-8"))
        inputfile.seek(0)
        storage.save(filename, inputfile)

        # trigger the lambda and wait for the produced file
        try:
            logger.info(f"{log_line_prefix}: triggering lambda")
            lambda_event_config = {
                "filename": filename,
                "is_casebook": export_type == "Casebook",
                "options": {
                    "word_footnotes": settings.FORCE_DOCX_FOOTNOTES
                    if docx_footnotes is None
                    else docx_footnotes,
                    "docx_sections": docx_sections,
                },
            }
            if export_settings.get("function_arn"):
                lambda_client = boto3.client(
                    "lambda",
                    export_settings["function_region"],
                    aws_access_key_id=export_settings["access_key"],
                    aws_secret_access_key=export_settings["secret_key"],
                    config=Config(read_timeout=settings.AWS_LAMBDA_EXPORT_TIMEOUT),
                )
                raw_response = lambda_client.invoke(
                    FunctionName=export_settings["function_name"],
                    LogType="Tail",
                    Payload=bytes(json.dumps(lambda_event_config), "utf-8"),
                )
                response = {
                    "status_code": raw_response["ResponseMetadata"]["HTTPStatusCode"],
                    "headers": raw_response["ResponseMetadata"]["HTTPHeaders"],
                    "content": raw_response["Payload"],
                    "get_text": lambda: raw_response["Payload"].read(),
                }
                lambda_log_str = (
                    str(base64.b64decode(raw_response["LogResult"]), "utf-8")
                    .strip()
                    .replace("\n", "; ")
                    .replace("\t", ", ")
                )
                logger.info(f'{log_line_prefix}: Lambda logs "{lambda_log_str}"')
            else:
                raw_response = requests.post(
                    export_settings["function_url"],
                    timeout=settings.AWS_LAMBDA_EXPORT_TIMEOUT,
                    json=lambda_event_config,
                )
                response = {
                    "status_code": raw_response.status_code,
                    "headers": {k.lower(): v for k, v in raw_response.headers.items()},
                    "log": None,
                    "content": raw_response.content,
                    "get_text": lambda: raw_response.text,
                }
            assert (
                response["status_code"] == 200
            ), f"Status: {response['status_code']}. Content: {response['get_text']()}"
            if response["headers"].get("content-type", "") == "text/plain; charset=utf-8":
                parsed_content = json.loads(response.get("content"))
                error_type = parsed_content.get("errorType", "Unknown")
                if error_type == "Function.ResponseSizeTooLarge":
                    raise LambdaExportTooLarge(
                        f"An HTML export of {len(html)} chars resulted in a {parsed_content.get('errorMessage')}"
                    )
            assert not response["headers"].get("x-amz-function-error") and response["headers"].get(
                "content-type", ""
            ) in [
                "application/zip",
                "application/octet-stream",
            ], f"x-amz-function-error: {response['headers'].get('x-amz-function-error')}, content-type:{response['headers'].get('content-type','unknown')}, {response['get_text']()}"
        except (BotoCoreError, BotoClientError, requests.RequestException, AssertionError) as e:
            if export_type == "Casebook":
                obj.inc_export_fails()
            raise Exception(f"AWS Lambda export failed: {str(e)}")
        finally:
            # remove the source html from s3
            storage.delete(filename)

        # return the docx to the user
        if export_type == "Casebook" and obj.export_fails > 0:
            obj.reset_export_fails()
        return response["content"]


class BadFiletypeError(Exception):
    pass


def validate_image(file, formats=None):
    if formats is None:
        formats = ["WEBP", "PNG", "JPEG", "GIF"]
    try:
        Image.open(file, formats=formats)
    except UnidentifiedImageError:
        raise BadFiletypeError(f"Only {', '.join(formats)} are supported at this time.")


def manually_serialize_content_query(content_query: QuerySet):
    """
    This method makes several interventions to substantially
    optimize the serialization process for casebooks and sections.
    As a result, it is messy, has to do many things. Handle with care.

    :param content_query: A django query of content to be serialized
        e.g. casebook.contents or section.contents
    :return: a serialized dictionary for use with frontend

    Given:
    >>> from main.models import ContentNode
    >>> _, legal_document_factory, casebook_factory, content_node_factory = [getfixture(i) for i in ['reset_sequences', 'legal_document_factory', 'casebook_factory', 'content_node_factory']]
    >>> casebook = casebook_factory()
    >>> nodes = [content_node_factory() for i in range(7)]
    >>> docs = [legal_document_factory() for i in range(7)]
    >>> nodes = [content_node_factory() for i in range(7)]
    >>> for i, (n, d) in enumerate(zip(nodes[:3], docs[:3])):
    ...     n.ordinals = (1, i + 1,)
    ...     n.resource_id = d.id
    ...     n.edit_url = ""
    ...     n.casebook_id = casebook.id
    ...     n.save()
    >>> for i, (n, d) in enumerate(zip(nodes[3:], docs[3:])):
    ...     n.ordinals = (1, 2, i+1)
    ...     n.resource_id = d.id
    ...     n.edit_url = ""
    ...     n.casebook_id = casebook.id
    ...     n.save()
    >>> nodes[6].ordinals = (1,)
    >>> nodes[6].resource_id = docs[6].id
    >>> nodes[6].save()
    >>> serialized = manually_serialize_content_query(casebook.contents)

	One top level section, as set up
    >>> assert len(serialized) == 1
    
    Serialized data has all expected keys
	>>> assert all([
	...     key in serialized[0].keys()
	...     for key in (
	...         "title",
	...         "id",
	...         "edit_url",
	...         "url",
	...         "citation",
	...         "decision_date",
	...         "is_transmutable",
	...         "ordinals",
	...         "ordinal_string",
	...         "children",
	...     )
	... ])

	Serialized data has correct children
	>>> assert [
	...     c["ordinals"] for c in serialized[0]["children"]
	... ] == [[1, 1], [1, 2], [1, 3]]

	Serialized data has the correct grandchildren
	>>> assert [
	...     c["ordinals"]
	...     for c in serialized[0]["children"][1]["children"]
	... ] == [[1, 2, 1], [1, 2, 2], [1, 2, 3]]
    """
    from .models import ContentAnnotation, LegalDocument
    from .serializers import ContentNodeSerializer

    toc = list(
        content_query.prefetch_resources(
            legal_doc_query=LegalDocument.objects.defer("content").all()
        )
        .order_by("ordinals")
        .annotate(
            has_annotation=Exists(ContentAnnotation.objects.filter(resource_id=OuterRef("pk")))
        )
        .select_related("casebook")
        .all()
    )
    # optimize expensive call to is_transmutable
    for t, t1 in zip(toc, toc[1:]):
        if not t.resource_type or t.resource_type == "Section" or t.resource_type == "":
            # if t1 is a child of t, then t is not transmutable
            t.transmutable = t.ordinals != t1.ordinals[: len(t.ordinals)]
    serialized = {tuple(c.ordinals): ContentNodeSerializer(c).data for c in toc}

    for cns in serialized.values():
        if cns["resource_type"] == "Section":
            cns["children"] = []

    serialized[()] = {"children": []}

    for ordinals, cns in serialized.items():
        if not ordinals:
            continue
        try:
            parent = serialized[ordinals[:-1]]
        except KeyError:
            # no parent, append to root
            parent = serialized[()]
        try:
            parent["children"].append(cns)
        except KeyError:
            raise ValueError("Trying to append children to non-Section!")
    return serialized[()]["children"]
