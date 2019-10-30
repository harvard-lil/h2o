from django.forms import ModelForm, Textarea
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Field, Div, HTML

from main.models import ContentNode, Default, TextBlock


class ContentNodeForm(ModelForm):

    class Meta:
        model = ContentNode
        fields = ['title', 'subtitle', 'headnote']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
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
    include fields for editing fields belonging to their related resource:
    Resource objects associated with Links/Defaults should have an editable
    "url" field, and Resource objects associated with TextBlocks should have
    an editable "content" field.

    To faciliate this, do NOT automatically render a `<form>` tag with this
    Django-Crispy-Form; create the form yourself in the the template, and then
    render this form, and if appropriate, a form for the related resource, inside.
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
        # These will be handled independently
        self.helper.form_tag = False
        self.helper.disable_csrf = True


class TextBlockForm(ModelForm):
    """
    For use along with ResourceForm; see ResourceForm for details.
    """

    # NB: I'm not safe to use yet!! We can't edit TextBlocks until we
    # implement the annotation-shifting logic on the python side.
    # I'm committing this for now, since the form itself works, and
    # then will add protections to prevent accidental edits in the
    # appropriate spot in another commit.

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
                HTML('<h5 id="content-label">Content (disabled)</h5>'),
                Field('content',
                    css_class='ckeditor',
                    aria_labelledby='content-label'
                ),
            )
        )
        # Disabled until it's safe to update TextBlocks
        self.fields['content'].disabled = True
        # Remove the explicit label on the "url" field, since it is
        # labeled using aria-labelledby
        self.fields['content'].label = False
        # These will be handled independently
        self.helper.form_tag = False
        self.helper.disable_csrf = True
