from unittest.mock import Mock

from django.urls import reverse
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


def test_collaborator_invite_existing(casebook_factory, faker, mailoutbox):
    """Don't try to create duplicate collaborators if they already exist"""
    email = faker.email()

    casebook = casebook_factory()
    form = InviteCollaboratorForm(data={"casebook": casebook.id, "email": email})
    assert form.is_valid()
    form.save(Mock())
    assert len(mailoutbox) == 1

    form = InviteCollaboratorForm(data={"casebook": casebook.id, "email": email})
    assert form.is_valid()
    form.save(Mock())
    assert len(mailoutbox) == 1  # Unchanged


def test_resourceform_user(full_private_casebook, client):
    """The resource form should only render the instructional toggle if the user is a verified professor"""
    user = full_private_casebook.testing_editor
    textblock_resource = full_private_casebook.resources.filter(resource_type="TextBlock").first()
    resp = client.get(
        reverse("edit_resource", args=[full_private_casebook, textblock_resource]), as_user=user
    )
    form = resp.context["form"]

    # Fourth item in the form layout is either the instructional checkbox, or an empty div
    instructional_div = form.helper.layout.fields[3]
    assert 0 == len(instructional_div.fields)

    user.verified_professor = True
    user.save()

    resp = client.get(
        reverse("edit_resource", args=[full_private_casebook, textblock_resource]), as_user=user
    )
    form = resp.context["form"]
    instructional_div = form.helper.layout.fields[3]

    # Now the container has a child, the instructional checkbox
    assert 1 == len(instructional_div.fields)
