import django.contrib.auth.forms as auth_forms
from crispy_forms.helper import FormHelper
from crispy_forms.layout import HTML, Div, Field, Layout, Submit
from django import forms
from django.conf import settings
from django.contrib.auth.models import Group
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.core.validators import URLValidator
from django.forms import ModelForm, Textarea
from django.urls import reverse

from main.models import (
    Casebook,
    ContentCollaborator,
    ContentNode,
    EmailWhitelist,
    Link,
    TextBlock,
    User,
)
from main.utils import (
    BadFiletypeError,
    fix_after_rails,
    send_collaboration_email,
    send_invitation_email,
    send_template_email,
    send_verification_email,
    validate_image,
)

# Monkeypatch FormHelper to *not* include the <form> tag in {% crispy form %} by default.
# Forms can opt back in with self.helper.form_tag = True. This is a more useful default
# because then we can use {% crispy form %} in built-in Django views like registration/password_change_form.html
# without having to override the form.
FormHelper.form_tag = False


class CasebookAndContentNodeMixin:
    class Meta:
        fields = ["title", "subtitle", "headnote"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = False
        self.helper.render_unmentioned_fields = True
        self.helper.layout = Layout(
            Field("title", placeholder="Enter a concise title."),
            Field("subtitle", placeholder="Subtitle (optional)"),
            Div(
                HTML('<h5 id="headnote-label">Headnote</h5>'),
                Field(
                    "headnote",
                    css_class="richtext-editor",
                    aria_labelledby="headnote-label",
                    placeholder="Enter any additional context about this casebook or section.",
                ),
            ),
        )
        # Remove the explicit label on the "headnote" field, since it is
        # labeled using aria-labelledby
        self.fields["headnote"].label = False


class ContentNodeForm(CasebookAndContentNodeMixin, ModelForm):
    class Meta(CasebookAndContentNodeMixin.Meta):
        model = ContentNode


class CasebookForm(CasebookAndContentNodeMixin, ModelForm):
    class Meta(CasebookAndContentNodeMixin.Meta):
        model = Casebook
        fields = list(CasebookAndContentNodeMixin.Meta.fields) + [
            "description",
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = "edit_content_casebook"
        self.helper.form_tag = False
        self.helper.layout = Layout(
            Field("title", placeholder="Enter a concise title."),
            Field("subtitle", placeholder="Subtitle (optional)"),
            Field("description", placeholder="Short description (optional)"),
            Div(
                HTML('<h5 id="headnote-label">Headnote</h5>'),
                Field(
                    "headnote",
                    css_class="richtext-editor",
                    aria_labelledby="headnote-label",
                    placeholder="Enter any additional context about this casebook or section.",
                ),
            ),
        )


class CasebookFormWithCoverImage(CasebookForm):
    class Meta(CasebookForm.Meta):
        fields = list(CasebookForm.Meta.fields) + ["cover_image"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

        cover_image_layout = Div(
            HTML('<h5 id="cover-image-label">Cover Image</h5>'),
            Field(
                "cover_image",
                aria_labelledby="cover-image-label",
            ),
        )
        self.helper.layout.fields.append(cover_image_layout)

    def clean_cover_image(self):
        cover_image = self.cleaned_data.get("cover_image")
        if cover_image:
            try:
                validate_image(cover_image)
            except BadFiletypeError as e:
                raise ValidationError(str(e))
        return cover_image


class SectionForm(ContentNodeForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = "edit_content_section"


class ResourceForm(ContentNodeForm):
    """
    The forms for editing a "Resource" ContentNode should, in some cases,
    include inputs for editing attributes of their related resource:
    Resource ContentNodes associated with Links should have an editable
    "url" field, and Resource ContentNodes associated with TextBlocks should have
    an editable "content" field.

    To facilitate this, we do NOT automatically render a `<form>` tag with this
    Django-Crispy-Form: `self.helper.form_tag = False`; instead, we explicitly
    include a form tag in the template, and then render ResourceForm form, and
    when appropriate, a LinkForm or TextBlockForm, inside it.
    See https://django-crispy-forms.readthedocs.io/en/latest/crispy_tag_forms.html#rendering-several-forms-with-helpers
    """

    does_display_ordinals = forms.BooleanField(
        label="Number this section in the table of contents", required=False
    )
    is_instructional_material = forms.BooleanField(
        label="This resource should only be displayed to other verified professors", required=False
    )

    class Meta:
        model = ContentNode
        fields = [
            "title",
            "subtitle",
            "does_display_ordinals",
            "headnote",
            "is_instructional_material",
        ]

    def __init__(self, *args, **kwargs):
        request = kwargs.pop("request", None)
        self.user = request.user if request else None

        super().__init__(*args, **kwargs)

        does_display_ordinals_options = (
            {"disabled": True} if self.instance.is_instructional_material else {}
        )

        is_instruction_material_layout = (
            Div(
                Field(
                    "is_instructional_material",
                    onClick=(
                        "document.querySelector('#id_does_display_ordinals').disabled=event.target.checked;"
                        "document.querySelector('#id_does_display_ordinals').checked=!event.target.checked;"
                    ),
                ),
                css_class="visible-in-form",
            )
            if self.instance.resource_type == "TextBlock"
            and self.user
            and User.user_can_view_instructional_material(self.user)
            else Div()
        )

        self.helper.layout = Layout(
            Field("title", placeholder="Enter a concise title."),
            Field("subtitle", placeholder="Subtitle (optional)"),
            Div(
                Field("does_display_ordinals", **does_display_ordinals_options),
                css_class="visible-in-form",
            ),
            is_instruction_material_layout,
            Div(
                HTML('<h5 id="headnote-label">Headnote</h5>'),
                Field(
                    "headnote",
                    css_class="richtext-editor",
                    aria_labelledby="headnote-label",
                    placeholder="Enter any additional context about this casebook or section.",
                ),
            ),
        )
        self.helper.form_class = "edit_content_resource"

    def save(self, commit=True):
        cn = self.instance
        # null reading_length so it can be recalculated later
        cn.reading_length = None
        super(ContentNodeForm, self).save()
        if (
            "does_display_ordinals" in self.changed_data
            or "is_instructional_material" in self.changed_data
        ):
            cn.content_tree__load()
            (cn.content_tree__parent or cn.casebook).content_tree__repair()
        return cn


class LinkForm(ModelForm):
    """
    For use along with ResourceForm; see ResourceForm for details.
    """

    class Meta:
        model = Link
        fields = ["url", "name"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            Div(
                HTML('<h5 id="url-label">URL</h5>'),
                Field("url", aria_labelledby="url-label", type="url"),
            )
        )
        # Remove the explicit label on the "url" field, since it is
        # labeled using aria-labelledby
        self.fields["url"].label = False
        self.helper.disable_csrf = True  # handled independently


class TextBlockForm(ModelForm):
    """
    For use along with ResourceForm; see ResourceForm for details.
    """

    class Meta:
        model = TextBlock
        fields = ["content"]
        widgets = {
            "content": Textarea(),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            Div(
                HTML('<h5 id="content-label">Content</h5>'),
                Field("content", css_class="richtext-editor", aria_labelledby="content-label"),
            )
        )
        # Remove the explicit label on the "content" field, since it is
        # labeled using aria-labelledby
        self.fields["content"].label = False
        self.helper.disable_csrf = True  # handled independently


class NewTextBlockForm(ModelForm):
    class Meta:
        model = TextBlock
        fields = ["name", "content"]


"""
URLValidator by default requires defining schema. Defaulting to https if not provided.
https://stackoverflow.com/questions/49983328/cleanest-way-to-allow-empty-scheme-in-django-urlfield
"""


class OptionalSchemeURLValidator(URLValidator):
    def __call__(self, value):
        if "://" not in value:
            value = "https://" + value
        super(OptionalSchemeURLValidator, self).__call__(value)


class UserProfileForm(ModelForm):
    class Meta:
        model = User
        fields = [
            "email_address",
            "attribution",
            "affiliation",
            "professor_verification_requested",
            "pronouns",
            "personal_site",
            "short_bio",
            "public_url",
        ]

    public_url = forms.CharField(
        label="Public url",
        help_text="Your public casebooks will be accessible at https://opencasebook.org/author/[public url]/",
        required=False,
    )

    personal_site = forms.CharField(
        label="Personal site link",
        initial="https://",
        required=False,
        validators=[OptionalSchemeURLValidator()],
    )

    short_bio = forms.CharField(
        label="Short Biography",
        help_text="Tell us a little bit about yourself (max 500 characters)",
        max_length=500,
        required=False,
        widget=forms.Textarea,
    )

    def __init__(self, *args, **kwargs):
        """
        All of the custom logic in this form is to handle the professor verification flow:

            - show a "Request Professor Verification" checkbox by default
            - if checked, switch the checkbox to a "Professor Verification Requested" message and send admins an email
            - if an admin sets verified_professor=True, change the message to "Verified Professor"
        """
        self.request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = True
        self.helper.layout = Layout(
            "email_address",
            "attribution",
            "pronouns",
            "personal_site",
            "short_bio",
            "affiliation",
            "public_url",
            (
                HTML(
                    '<div class="verified-professor">Verified Professor<span class="verified"></span></div>'
                )
                if self.instance.verified_professor
                else (
                    HTML('<div class="verified-professor">Professor Verification Requested</div>')
                    if self.instance.professor_verification_requested
                    else "professor_verification_requested"
                )
            ),
            Submit("submit", "Save changes"),
            HTML(
                f'<a href="{reverse("password_change")}" class="btn btn-default">Change your password</a>'
            ),
        )
        if self.instance.professor_verification_requested or self.instance.verified_professor:
            self.fields.pop("professor_verification_requested")
        else:
            self.fields["professor_verification_requested"].label = "Request Professor Verification"
        fix_after_rails(
            "setting email_address.required to True manually until the field is required in the model"
        )
        self.fields["email_address"].required = True

    def clean_public_url(self):
        public_url = self.cleaned_data["public_url"]
        if public_url == "":
            return None
        return public_url

    def save(self, commit=True):
        # Add protocol if not provided
        if self.instance.personal_site and "://" not in self.instance.personal_site:
            self.instance.personal_site = "https://" + self.cleaned_data["personal_site"]

        super(UserProfileForm, self).save()
        # let admin know of professor verification requests
        user = self.instance
        if (
            user.professor_verification_requested
            and "professor_verification_requested" in self.changed_data
        ):
            admin_user_link = self.request.build_absolute_uri(
                reverse("h2oadmin:main_user_change", args=[user.id])
            )
            message = f"Verify {user}: {admin_user_link}\nAffiliation: {user.affiliation}\nEmail address: {user.email_address}"
            send_mail(
                f"H2O Professor Verification Request for {user}",
                message,
                settings.DEFAULT_FROM_EMAIL,
                settings.PROFESSOR_VERIFIER_EMAILS,
            )


class SignupForm(ModelForm):

    user_groups = forms.MultipleChoiceField(
        choices=(
            ("Professor", "Professor or Lecturer"),
            (
                "Student",
                "Student",
            ),
            (
                "Librarian",
                "Librarian",
            ),
            ("Other", "Other"),
        ),
        required=False,
        widget=forms.widgets.CheckboxSelectMultiple(),
    )

    class Meta:
        model = User
        fields = ["email_address", "user_groups"]
        widgets = {
            "email_address": forms.EmailInput(),
        }

    def __init__(self, *args, **kwargs):
        self.request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = True
        self.fields["user_groups"].label = False
        self.helper.layout = Layout(
            "email_address",
            Div(
                HTML("I am a..."),
                "user_groups",
            ),
            Submit("submit", "Sign up"),
            HTML(
                f'<p class="help-block">By signing up for an account, you agree to our <a href="{reverse("terms-of-service")}">Terms of Service</a>.</p>'
            ),
        )
        self.fields[
            "email_address"
        ].help_text = """<p class="help-block">Registration is restricted to email addresses belonging to an educational or government institution. 
        If your email address doesn't work and you believe it should, please 
        <a href="mailto:info@opencasebook.org?subject=Whitelist%20University%20Email&body=Hello%20H2O,%A0Please%20whitelist%20my%20email%20domain.">let us know</a>.</p>
        """

    def clean_email_address(self):
        email = self.cleaned_data["email_address"]
        if email:
            if email.endswith(".edu") or email.endswith(".gov") or email.endswith(".ac.uk"):
                return email
            domain = email.split("@")[-1]
            valid_domains = set([e.email_domain for e in EmailWhitelist.objects.all()])
            if domain not in valid_domains:
                raise ValidationError(
                    "Email address doesn't belong to a known educational or government institution. Please contact us."
                )
        return email

    def save(self, commit=True):
        self.instance.set_password(User.objects.make_random_password(length=20))
        user = ModelForm.save(self, True)
        for user_group in self.cleaned_data["user_groups"]:
            if group := Group.objects.filter(name=user_group).first():
                user.groups.add(group)

        send_verification_email(self.request, user)
        return user


class SetPasswordForm(auth_forms.SetPasswordForm):
    def save(self, commit=True):
        """
        When allowing user to set their password via an email link, we may be in a new-user flow with
        is_active=False, or a forgot-password flow with is_active=True.
        """
        if not self.user.is_active:
            # new-user flow:
            self.user.is_active = True
            send_template_email(
                "Welcome to H2O!",
                "email/welcome.txt",
                {},
                settings.DEFAULT_FROM_EMAIL,
                [self.user.email_address],
            )
        return super().save(commit)


class CasebookSettingsTransitionForm(forms.Form):
    transition_to = forms.CharField(max_length=10)


class CollaboratorFormSet(forms.BaseModelFormSet):
    def clean(self):
        if any(self.errors):
            return
        at_least_one_editor = (
            len(
                [
                    form.cleaned_data.get("can_edit")
                    for form in self.forms
                    if form.cleaned_data.get("can_edit", False)
                    and not form.cleaned_data.get("DELETE", False)
                ]
            )
            > 0
        )
        if not at_least_one_editor:
            raise forms.ValidationError("At least one collaborator must be able to edit.")


class InviteCollaboratorForm(forms.Form):
    casebook = forms.IntegerField(widget=forms.HiddenInput(), required=True)
    email = forms.EmailField(required=True)
    helper = FormHelper()

    def clean_email(self):
        [email_user, email_domain] = self.cleaned_data["email"].split("@")
        return f"{email_user}@{email_domain.lower()}"

    def save(self, request, commit=True) -> None:
        email_address = self.cleaned_data["email"]
        casebook = Casebook.objects.get(id=self.cleaned_data["casebook"])

        if user := User.objects.filter(email_address__iexact=email_address).first():
            # If this user exists and is not yet a collaborator, create them and notify them via email
            if ContentCollaborator.objects.filter(user=user, casebook=casebook).count() == 0:
                ContentCollaborator.objects.create(
                    has_attribution=False, can_edit=False, user=user, casebook=casebook
                )
                send_collaboration_email(request, user, casebook)
        else:
            user = User.objects.create(email_address=email_address)
            ContentCollaborator.objects.create(
                has_attribution=False, can_edit=False, user=user, casebook=casebook
            )
            send_invitation_email(request, user, casebook)
