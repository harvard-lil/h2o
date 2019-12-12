import re

from django.urls import reverse

from test.test_helpers import check_response

"""
    Tests for built-in Django auth views -- change password flow and forgot password flow.
"""

def test_change_password(user, client):
    user.set_password('old_password')
    user.save()
    client.force_login(user)

    # visit form
    check_response(client.get(reverse('password_change')), content_includes=['Change your password'])

    # try to change with wrong password
    check_response(client.post(
        reverse('password_change'),
        {'old_password': 'wrong', 'new_password1': 'new_password', 'new_password2': 'new_password'},
    ), content_includes=['Your old password was entered incorrectly.'])

    # password not updated
    user.refresh_from_db()
    assert user.check_password('old_password')

    # try to change with correct password
    check_response(client.post(
        reverse('password_change'),
        {'old_password': 'old_password', 'new_password1': 'new_password', 'new_password2': 'new_password'},
        follow=True,
    ), content_includes=['Your password has been updated.'])

    # password has been updated
    user.refresh_from_db()
    assert user.check_password('new_password')


def test_forgot_password(user, client, mailoutbox):
    user.set_password('old_password')
    user.save()

    # request reset email
    check_response(client.get(reverse('password_reset')), content_includes=['Forgotten your password?'])
    check_response(client.post(reverse('password_reset'), {'email': user.email_address}, follow=True), content_includes=["We've emailed you instructions"])

    # submit new password
    assert len(mailoutbox) == 1
    reset_url = re.search(r'(http:.*)', mailoutbox[0].body).group(0)
    new_password_form_response = client.get(reset_url, follow=True)
    check_response(new_password_form_response, content_includes=['Please enter your new password'])
    post_url = new_password_form_response.redirect_chain[0][0]
    check_response(client.post(post_url, {'new_password1': 'new_password', 'new_password2': 'new_password'}, follow=True), content_includes=['Your password has been updated'])

    # password changed
    user.refresh_from_db()
    assert user.check_password('new_password')

    # since they use the same flow... verify that the "new user" email wasn't sent
    assert len(mailoutbox) == 1
