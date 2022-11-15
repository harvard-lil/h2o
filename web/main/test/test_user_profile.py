import pytest
from pytest_django.asserts import assertContains
from django.urls import reverse

from conftest import UserFactory


def test_edit_user_profile(user, client):
    """Users should be able to request professor verification from the profile page"""

    resp = client.get(reverse("edit_user"), as_user=user)
    assertContains(resp, "Request Professor Verification")

    resp = client.post(
        reverse("edit_user"),
        {
            "professor_verification_requested": "on",
            "email_address": user.email_address,
            "affiliation": user.affiliation,
            "attribution": user.attribution,
        },
        as_user=user,
        follow=True,
    )
    assertContains(resp, "Your changes have been saved")
    assertContains(resp, "Professor Verification Requested")


@pytest.mark.parametrize("is_verified_professor,num_messages", [[True, 0], [False, 1]])
@pytest.mark.django_db
def test_email_for_verification(is_verified_professor, num_messages, client, mailoutbox):
    """Only unverified users should trigger a professor verification email"""
    user = UserFactory(verified_professor=is_verified_professor)

    assert len(mailoutbox) == 0

    client.post(
        reverse("edit_user"),
        {
            "professor_verification_requested": "on",
            "email_address": user.email_address,
            "affiliation": user.affiliation,
            "attribution": user.attribution,
        },
        as_user=user,
        follow=True,
    )
    assert len(mailoutbox) == num_messages
