from django.forms import Form, ModelForm
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Field, Div, HTML

from main.models import Casebook


class CasebookForm(ModelForm):

    class Meta:
        model = Casebook
        fields = ['title', 'subtitle', 'headnote']

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.form_class = 'simple_form edit_content_casebook'
        self.helper.layout = Layout(
            Field('title', placeholder='Enter a concise title.'),
            Field('subtitle', placeholder='Subtitle (optional)'),
            Div(
                HTML('<h5 id="headnote-label">Headnote</h5>'),
                Field('headnote',
                    css_class='ckeditor',
                    aria_labelledby='headnote-label',
                    placeholder='Enter any additional context about this casebook or section.'
                )
            )
        )
        # Remove the explicit label on the "headnote" field, since it is
        # labeled using aria-labelledby
        self.fields['headnote'].label = False
