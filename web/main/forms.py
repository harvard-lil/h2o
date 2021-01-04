from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Field, Div, HTML, Submit

import django.contrib.auth.forms as auth_forms
from django.conf import settings

from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.forms import ModelForm, Textarea
from django import forms
from django.urls import reverse

from main.models import ContentNode, Link, TextBlock, User, EmailWhitelist, ContentCollaborator, Casebook
from main.utils import fix_after_rails, send_template_email, send_verification_email, send_invitation_email, send_collaboration_email


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
        self.helper.form_tag = False
        self.helper.render_unmentioned_fields = True
        self.helper.layout = Layout(
            Field('title', placeholder='Enter a concise title.'),
            Field('subtitle', placeholder='Subtitle (optional)'),
            Div(
                HTML('<h5 id="headnote-label">Headnote</h5>'),
                Field('headnote',
                    css_class='richtext-editor',
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
        self.helper.form_tag = False


class SectionForm(ContentNodeForm):

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = 'edit_content_section'


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

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper.form_class = 'edit_content_resource'


class LinkForm(ModelForm):
    """
    For use along with ResourceForm; see ResourceForm for details.
    """

    class Meta:
        model = Link
        fields = ['url', 'name']

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
                    css_class='richtext-editor',
                    aria_labelledby='content-label'
                ),
            )
        )
        # Remove the explicit label on the "content" field, since it is
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
        fields = ['email_address', 'attribution', 'affiliation', 'professor_verification_requested', 'public_url']
    public_url = forms.CharField(label="Public url",help_text="Your public casebooks will be accessible at https://opencasebook.org/author/[public url]/", required=False)

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
            'email_address', 'attribution', 'affiliation','public_url',
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

    def clean_public_url(self):
        public_url = self.cleaned_data['public_url']
        if public_url == '':
            return None
        return public_url

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
        self.fields['email_address'].help_text = '<p class="help-block">Registration is restricted to email addresses belonging to an educational or government institution. If your email address doesn\'t work and you believe it should, please <a href="mailto:info@opencasebook.org?subject=Whitelist%20University%20Email&body=Hello%20H2O,%A0Please%20whitelist%20my%20email%20domain.">Let us know</a></p>'

    def clean_email_address(self):
        email = self.cleaned_data['email_address']
        if email:
            if email.endswith(".edu") or email.endswith(".gov") or email.endswith(".ac.uk"):
                return email
            domain = email.split("@")[-1]
            valid_domains = set([e.email_domain for e in EmailWhitelist.objects.all()])
            if domain not in valid_domains:
                raise ValidationError("Email address is not .edu or .gov.")
        return email

    def save(self, commit=True):
        # save user
        self.instance.set_password(User.objects.make_random_password(length=20))
        user = ModelForm.save(self, True)
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
                'email/welcome.txt',
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
        at_least_one_editor = len([form.cleaned_data.get('can_edit') for form in self.forms if form.cleaned_data.get('can_edit', False) and not form.cleaned_data.get('DELETE', False)]) > 0
        if not at_least_one_editor:
            raise forms.ValidationError("At least one collaborator must be able to edit.")


class InviteCollaboratorForm(forms.Form):
    casebook = forms.IntegerField(widget=forms.HiddenInput())
    email = forms.EmailField()
    helper = FormHelper()

    def save(self, request, commit=True):
        email_address = self.cleaned_data.get('email', None)
        casebook = Casebook.objects.get(id=self.cleaned_data.get('casebook', None))

        user = User.objects.filter(email_address=email_address).first()
        collaborator = None
        if not user:
            user = User.objects.create(email_address=email_address)
            collaborator = ContentCollaborator.objects.create(has_attribution=False, can_edit=False, user=user, casebook=casebook)
            send_invitation_email(request, user, casebook)
        else:
            collaborator = ContentCollaborator.objects.create(has_attribution=False, can_edit=False, user=user, casebook=casebook)
            send_collaboration_email(request, user, casebook)

        return collaborator
