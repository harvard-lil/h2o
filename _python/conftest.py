import re

import pytest

import factory
from django.test import Client
from django.urls import reverse
from django.utils import timezone
from rest_framework.response import Response

from main.models import ContentNode, User, Casebook, Section, Resource, ContentCollaborator


# This file defines test fixtures available to all tests.
# To see available fixtures run pytest --fixtures


### helpers ###

def register_factory(cls):
    """
        Decorator to take a factory class and inject test fixtures. For example,

            @register_factory
            class UserFactory

        will inject the fixtures "user_factory" (equivalent to UserFactory) and "user" (equivalent to UserFactory()).

        This is basically the same as the @register decorator provided by the pytest_factoryboy package,
        but because it's simpler it seems to work better with RelatedFactory and SubFactory.
    """
    camel_case_name = re.sub('((?<=[a-z0-9])[A-Z]|(?!^)[A-Z](?=[a-z]))', r'_\1', cls.__name__).lower()
    globals()[camel_case_name] = pytest.fixture(lambda: cls)
    globals()[camel_case_name.rsplit('_factory', 1)[0]] = pytest.fixture(lambda: cls())
    return cls


### model factories ###

@register_factory
class UserFactory(factory.DjangoModelFactory):
    class Meta:
        model = User

    persistence_token = ''
    login_count = 0
    attribution = "some name"
    print_titles = True
    print_dates_details = True
    print_paragraph_numbers = True
    print_annotations = True
    print_highlights = ''
    print_font_face = ''
    print_font_size = ''
    default_show_comments = True
    default_show_paragraph_numbers = True
    hidden_text_display = True
    print_links = True
    toc_levels = ''
    print_export_format = ''
    verified_email = True


@register_factory
class ContentNodeFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentNode

    public = True
    cloneable = True
    created_at = timezone.now()
    ordinals=[]


@register_factory
class CasebookFactory(ContentNodeFactory):
    class Meta:
        model = Casebook

    contentcollaborator_set = factory.RelatedFactory('conftest.ContentCollaboratorFactory', 'content')
    title = factory.Sequence(lambda n: 'Some Title %s' % n)


@register_factory
class SectionFactory(ContentNodeFactory):
    class Meta:
        model = Section

    casebook = factory.SubFactory(CasebookFactory)


@register_factory
class ResourceFactory(ContentNodeFactory):
    class Meta:
        model = Resource

    casebook = factory.SubFactory(CasebookFactory)
    # todo:
    resource_type = "todo"
    resource_id = 999


@register_factory
class ContentCollaboratorFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentCollaborator

    user = factory.SubFactory(UserFactory)
    content = factory.SubFactory(CasebookFactory)
    role = 'owner'
    created_at = timezone.now()
    updated_at = timezone.now()
    has_attribution = True


### fixture functions ###

# these can be injected on demand with getfixture() in doctests, or as function arguments in test files

@pytest.fixture
def content_node_tree(content_node_factory, db):
    """
        Return a list of ContentNodes representing a tree like:
            - root
                - c_1
                    - c_1_1
                    - c_1_2
                - c_2
    """
    root = content_node_factory()
    c_1 = content_node_factory(ancestry=str(root.id))
    c_2 = content_node_factory(ancestry=str(root.id))
    c_1_1 = content_node_factory(ancestry="%s/%s" % (c_1.ancestry, c_1.id))
    c_1_2 = content_node_factory(ancestry="%s/%s" % (c_1.ancestry, c_1.id))
    return [root, c_1, c_2, c_1_1, c_1_2]


@pytest.fixture
def user_client(db, user_factory):
    """
        Return a test client logged in as a new user.
    """
    client = Client()
    user = user_factory()
    # TODO: force_login uses Django auth system; need to patch
    # client.force_login(user=user)
    client.user = user  # make user available to tests
    return client


### global functions ###

# these are injected into the namespace for all doctests by inject_helpers

def check_response(response, status_code=200, content_type=None, content_includes=None, content_excludes=None):
    assert response.status_code == status_code

    # check content-type if not a redirect
    if response['content-type']:
        # For rest framework response, expect json; else expect html.
        if not content_type:
            if type(response) == Response:
                content_type = "application/json"
            else:
                content_type = "text/html"
        assert response['content-type'].split(';')[0] == content_type

    if content_includes:
        assert content_includes in response.content.decode()
    if content_excludes:
        assert content_excludes not in response.content.decode()


@pytest.fixture(autouse=True)
def inject_helpers(doctest_namespace):
    doctest_namespace["check_response"] = check_response
    doctest_namespace["reverse"] = reverse