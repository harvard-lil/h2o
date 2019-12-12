from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Field, Div, HTML, Submit

import django.contrib.auth.forms as auth_forms
from django.conf import settings
from django.contrib.auth.tokens import default_token_generator
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.forms import ModelForm, Textarea
from django.urls import reverse
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

from main.models import ContentNode, Default, TextBlock, User
from main.utils import fix_after_rails, send_template_email


# Monkeypatch FormHelper to *not* include the <form> tag in {% crispy form %} by default.
# Forms can opt back in with self.helper.form_tag = True. This is a more useful default
# because then we can use {% crispy form %} in built-in Django views like registration/password_change_form.html
# without having to override the form.
FormHelper.form_tag = False


class ContentNodeForm(ModelForm):

    class Meta:
        model = ContentNode
        fields = ['title', 'subtitle', 'headnote']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = True
        self.helper.render_unmentioned_fields = True
        self.helper.layout = Layout(
            Field('title', placeholder='Enter a concise title.'),
            Field('subtitle', placeholder='Subtitle (optional)'),
            Div(
                HTML('<h5 id="headnote-label">Headnote</h5>'),
                Field('headnote',
                    css_class='ckeditor',
                    aria_labelledby='headnote-label',
                    placeholder='Enter any additional context about this casebook or section.'
                ),
            )
        )
        # Remove the explicit label on the "headnote" field, since it is
        # labeled using aria-labelledby
        self.fields['headnote'].label = False


class CasebookForm(ContentNodeForm):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = 'edit_content_casebook'


class SectionForm(ContentNodeForm):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = 'edit_content_section'


class ResourceForm(ContentNodeForm):
    """
    The forms for editing a "Resource" ContentNode should, in some cases,
    include inputs for editing attributes of their related resource:
    Resource ContentNodes associated with Links/Defaults should have an editable
    "url" field, and Resource ContentNodes associated with TextBlocks should have
    an editable "content" field.

    To facilitate this, we do NOT automatically render a `<form>` tag with this
    Django-Crispy-Form: `self.helper.form_tag = False`; instead, we explicitly
    include a form tag in the template, and then render ResourceForm form, and
    when appropriate, a LinkForm or TextBlockForm, inside it.
    See https://django-crispy-forms.readthedocs.io/en/latest/crispy_tag_forms.html#rendering-several-forms-with-helpers
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = 'edit_content_resource'
        self.helper.form_tag = False


class LinkForm(ModelForm):
    """
    For use along with ResourceForm; see ResourceForm for details.
    """

    class Meta:
        model = Default
        fields = ['url']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            Div(
                HTML('<h5 id="url-label">URL</h5>'),
                Field('url',
                    aria_labelledby='url-label'
                ),
            )
        )
        # Remove the explicit label on the "url" field, since it is
        # labeled using aria-labelledby
        self.fields['url'].label = False
        self.helper.disable_csrf = True  # handled independently


class TextBlockForm(ModelForm):
    """
    For use along with ResourceForm; see ResourceForm for details.
    """

    class Meta:
        model = TextBlock
        fields = ['content']
        widgets = {
            'content': Textarea(),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            Div(
                HTML('<h5 id="content-label">Content</h5>'),
                Field('content',
                    css_class='ckeditor',
                    aria_labelledby='content-label'
                ),
            )
        )
        # Remove the explicit label on the "url" field, since it is
        # labeled using aria-labelledby
        self.fields['content'].label = False
        self.helper.disable_csrf = True  # handled independently


class NewTextBlockForm(ModelForm):

    class Meta:
        model = TextBlock
        fields = ['name', 'content']


class UserProfileForm(ModelForm):
    class Meta:
        model = User
        fields = ['email_address', 'attribution', 'affiliation', 'professor_verification_requested']

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
            'email_address', 'attribution', 'affiliation',
            (
                HTML('<div class="verified-professor">Verified Professor<span class="verified"></span></div>') if self.instance.verified_professor else
                HTML('<div class="verified-professor">Professor Verification Requested</div>') if self.instance.professor_verification_requested else
                'professor_verification_requested'
            ),
            Submit('submit', 'Save changes'),
            HTML('<a href="%s" class="btn btn-default">Change your password</a>' % reverse('password_change')),
        )
        if self.instance.professor_verification_requested or self.instance.verified_professor:
            self.fields.pop('professor_verification_requested')
        else:
            self.fields['professor_verification_requested'].label = 'Request Professor Verification'
        fix_after_rails("setting email_address.required to True manually until the field is required in the model")
        self.fields['email_address'].required = True

    def save(self, commit=True):
        super(UserProfileForm, self).save()

        # let admin know of professor verification requests
        user = self.instance
        if user.professor_verification_requested and 'professor_verification_requested' in self.changed_data:
            message = "Verify %s: %s\nAffiliation: %s\nEmail address: %s" % (
                user,
                self.request.build_absolute_uri(reverse('h2oadmin:main_user_change', args=[user.id])),
                user.affiliation,
                user.email_address)
            send_mail(
                "H2O Professor Verification Request for %s" % user,
                message,
                settings.DEFAULT_FROM_EMAIL,
                settings.PROFESSOR_VERIFIER_EMAILS
            )


class SignupForm(ModelForm):
    class Meta:
        model = User
        fields = ['email_address']

    def __init__(self, *args, **kwargs):
        self.request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_tag = True
        self.helper.layout = Layout(
            'email_address',
            Submit('submit', 'Sign up'),
            HTML('<p class="help-block">By signing up for an account, you agree to our <a href="%s">Terms of Service</a>.</p>' % reverse('terms-of-service')),
        )
        self.fields['email_address'].help_text = '<p class="help-block">Registration is restricted to email addresses that end in <code>.edu</code>.</p>'

    def clean_email_address(self):
        email = self.cleaned_data['email_address']
        if not email.endswith(".edu"):
            raise ValidationError("Email address is not .edu.")
        return email

    def save(self, commit=True):
        # save user
        self.instance.password_salt = User.objects.make_random_password(length=20)
        self.instance.set_password(User.objects.make_random_password(length=20))
        user = ModelForm.save(self, True)

        # Send verify-email-address email.
        # This uses the forgot-password flow; logic is borrowed from auth_forms.PasswordResetForm.save()
        verify_link = self.request.build_absolute_uri(reverse('password_reset_confirm', args=[
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

        return user


class PasswordResetForm(auth_forms.PasswordResetForm):
    def get_users(self, email):
        """ Override get_users() to use verified_email field instead of is_active field. """
        fix_after_rails("consider renaming verified_email to is_active and dropping this custom form")
        active_users = User.objects.filter(email_address=email, verified_email=True)
        return (u for u in active_users if u.has_usable_password())


class SetPasswordForm(auth_forms.SetPasswordForm):
    def save(self, commit=True):
        """
            When allowing user to set their password via an email link, we may be in a new-user flow with
            verified_email=False, or a forgot-password flow with verified_email=True.
        """
        if not self.user.verified_email:
            # new-user flow:
            self.user.verified_email = True
            send_template_email(
                "Welcome to H2O!",
                'email/welcome.txt',
                {},
                settings.DEFAULT_FROM_EMAIL,
                [self.user.email_address],
            )
        return super().save(commit)
