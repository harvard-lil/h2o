from django.urls import register_converter
from django.urls.converters import IntConverter

from .models import Casebook, Section


class ModelConverterMixin:
    """
        Via https://consideratecode.com/2018/05/11/the-hidden-powers-of-custom-django-2-0-path-converters/
    """
    def get_queryset(self):
        if self.queryset:
            return self.queryset.all()
        return self.model.objects.all()

    def to_python(self, value):
        try:
            return self.get_queryset().get(**{self.field: super().to_python(value)})
        except self.model.DoesNotExist:
            raise ValueError

    def to_url(self, obj):
        if not isinstance(obj, self.model):
            return ''
        return super().to_url(getattr(obj, self.field))


def register_model_converter(model, name=None, field='pk', base=IntConverter, queryset=None):
    if name is None:
        name = model.__name__.lower()
    converter_name = '{}Converter'.format(name.capitalize())
    converter_class = type(
        converter_name,
        (ModelConverterMixin, base,),
        {'model': model, 'field': field, 'queryset': queryset}
    )
    register_converter(converter_class, name)


class IdSlugConverter:
    # matches:
    # 2, 2-, 22-slug, etc.
    regex = r'[0-9]+(\-[^/]*)?'

    def to_python(self, value):
        id_slug = value.split('-', 1)
        try:
            slug = id_slug[1]
        except IndexError:
            slug = ''
        return {
            'id': int(id_slug[0]),
            'slug': slug
        }

    @staticmethod
    def to_url(value):
        """
            >>> assert IdSlugConverter.to_url(1) == "1"
            >>> assert IdSlugConverter.to_url({"id": 1}) == "1"
            >>> assert IdSlugConverter.to_url({"id": 1, "slug": "foo"}) == "1-foo"
            >>> assert IdSlugConverter.to_url(Casebook(id=1, title="foo")) == "1-foo"
        """
        if hasattr(value, 'id'):
            id = value.id
            slug = value.get_slug()
        elif isinstance(value, int):
            id = value
            slug = None
        elif isinstance(value, dict):
            id = value['id']
            slug = value.get('slug')
        else:
            raise ValueError("Cannot create IdSlug from argument type %s" % type(value))
        return str(id) + (("-%s" % slug) if slug else "")


class OrdinalSlugConverter:
    # matches:
    # 2, 2.2, 22.2.22, 2-, 2-slug, 2.22.2-, 2.2.22-slug, etc.
    regex = r'([0-9]+\.)*[0-9]+(\-[^/]*)?'

    def to_python(self, value):
        ord_slug = value.split('-', 1)
        try:
            slug = ord_slug[1]
        except IndexError:
            slug = ''
        return {
            'ordinals': [int(i) for i in ord_slug[0].split('.')],
            'slug': slug
        }

    @staticmethod
    def to_url(value):
        """
            >>> assert OrdinalSlugConverter.to_url({"ordinals": [1, 2]}) == "1.2"
            >>> assert OrdinalSlugConverter.to_url({"ordinals": [1, 2], "slug": "foo"}) == "1.2-foo"
            >>> assert OrdinalSlugConverter.to_url(Section(ordinals=[1, 2], title="foo")) == "1.2-foo"
        """
        if hasattr(value, 'ordinals'):
            ordinals = value.ordinals
            slug = value.get_slug()
        elif isinstance(value, dict):
            ordinals = value['ordinals']
            slug = value.get('slug')
        elif isinstance(value, str):
            return value
        else:
            raise ValueError("Cannot create OrdinalSlug from argument type %s" % type(value))
        return '.'.join(str(i) for i in ordinals) + (("-%s" % slug) if slug else "")

