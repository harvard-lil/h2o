import pytest

from django.conf import settings
from django.urls import reverse

from test.test_helpers import check_response


@pytest.mark.parametrize('error', ['400', '403', '404', '500'])
def test_error_pages(error, client_with_raise_request_exception, mailoutbox):
    """
    Verify that our injected context variables are present.
    """
    client = client_with_raise_request_exception(
        raise_request_exception=False
    )
    check_response(client.get(reverse(error)), status_code=int(error), content_includes=
        settings.CONTACT_EMAIL,
    )
    if error == '500':
        [email] = mailoutbox
        assert 'Internal Server Error' in email.subject
    elif error == '400':
        [email] = mailoutbox
        assert 'Fishy' in email.subject
    else:
        assert len(mailoutbox) == 0


def test_csrf_error_page(client_with_raise_request_exception):
    """
    Verify that our injected context variables are present.
    """
    client = client_with_raise_request_exception(
        raise_request_exception=False,
        enforce_csrf_checks=True
    )
    check_response(client.post(reverse('403_csrf')), status_code=403, content_includes=
        settings.CONTACT_EMAIL,
    )
