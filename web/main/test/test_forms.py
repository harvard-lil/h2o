from unittest.mock import Mock
from main.forms import InviteCollaboratorForm
from main.models import User


def test_collaborator_invite(casebook_factory, faker):
    """Inviting the same user with differently-cased email addresses should
    not result in duplicate users."""

    # Given a new email address...
    email = faker.email()
    assert User.objects.filter(email_address__iexact=email).count() == 0

    # Invite that email address to a casebook
    casebook = casebook_factory()
    form = InviteCollaboratorForm(data={"casebook": casebook.id, "email": email})
    assert form.is_valid()
    form.save(Mock())
    assert User.objects.filter(email_address__iexact=email).count() == 1

    # Invite the same email address with different case to a different casebook
    casebook = casebook_factory()
    form = InviteCollaboratorForm(data={"casebook": casebook.id, "email": email.upper()})
    assert form.is_valid()
    form.save(Mock())

    # Only one user is created
    assert User.objects.filter(email_address__iexact=email).count() == 1
