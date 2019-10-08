import re
import pytest
import factory

from django.urls import reverse
from django.utils import timezone
from rest_framework.response import Response

from main.models import ContentNode, User, Casebook, Section, Resource, ContentCollaborator, Role, Default, TextBlock, \
    Case, CaseCourt


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

    @pytest.fixture
    def factory_fixture(db):
        return cls

    @pytest.fixture
    def instance_fixture(db):
        return cls()

    globals()[camel_case_name] = factory_fixture
    globals()[camel_case_name.rsplit('_factory', 1)[0]] = instance_fixture

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
    verified_professor = False
    professor_verification_requested = False


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
    ordinals = [1]


@register_factory
class ResourceFactory(ContentNodeFactory):
    class Meta:
        model = Resource

    casebook = factory.SubFactory(CasebookFactory)
    resource_type = None
    resource_id = None


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


@register_factory
class DefaultFactory(factory.DjangoModelFactory):
    # actually Link
    class Meta:
        model = Default

    name = factory.Sequence(lambda n: 'Some Link Name %s' % n)
    description = factory.Sequence(lambda n: 'Some Link Description %s' % n)
    url = factory.Sequence(lambda n: 'https://example.com/%s' % n)
    public = True
    created_via_import = False
    user = factory.SubFactory(UserFactory)


@register_factory
class TextBlockFactory(factory.DjangoModelFactory):
    class Meta:
        model = TextBlock

    name = factory.Sequence(lambda n: 'Some TextBlock Name %s' % n)
    description = factory.Sequence(lambda n: 'Some TextBlock Description %s' % n)
    content = factory.Sequence(lambda n: 'Some TextBlock Content %s' % n)
    version = 1
    public = True
    created_via_import = False
    annotations_count = 0
    user = factory.SubFactory(UserFactory)
    enable_feedback = True
    enable_discussions = True
    enable_responses = True


@register_factory
class CaseCourtFactory(factory.DjangoModelFactory):
    class Meta:
        model = CaseCourt

    name_abbreviation = factory.Sequence(lambda n: 'Sm. Ct. Name Abbrev. %s' % n)
    name = factory.Sequence(lambda n: 'Some Court Name %s' % n)


@register_factory
class CaseFactory(factory.DjangoModelFactory):
    class Meta:
        model = Case

    name_abbreviation = factory.Sequence(lambda n: 'Foo%s v. Bar%s' % (n, n))
    name = factory.Sequence(lambda n: 'Foo Foo%s vs. Bar Bar%s' % (n, n))
    public = True
    created_via_import = False
    content = factory.Sequence(lambda n: 'Some Case Content %s' % n)
    annotations_count = 0
    case_court = factory.SubFactory(CaseCourtFactory)

### fixture functions ###

# these can be injected on demand with getfixture() in doctests, or as function arguments in test files

@pytest.fixture
def content_node_tree(content_node_factory):
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
def admin_user(user_factory):
    user = user_factory()
    role, created = Role.objects.get_or_create(name='superadmin')
    user.roles.add(role)
    return user


@pytest.fixture
def full_casebook(casebook_factory):
    """
        Create:
            - owner
            - casebook
                - section
                    - resource -> textblock
                    - resource -> case
                    - resource -> link
                    - resource -> textblock
                    - resource -> case
                    - resource -> link
    """
    user = UserFactory()
    casebook = casebook_factory(contentcollaborator_set__user=user)
    SectionFactory(casebook=casebook)
    ResourceFactory(casebook=casebook, ordinals=[1, 1], resource_type='TextBlock', resource_id=TextBlockFactory(user=user).id)
    ResourceFactory(casebook=casebook, ordinals=[1, 2], resource_type='Case', resource_id=CaseFactory().id)
    ResourceFactory(casebook=casebook, ordinals=[1, 3], resource_type='Default', resource_id=DefaultFactory(user=user).id)
    ResourceFactory(casebook=casebook, ordinals=[1, 4], resource_type='TextBlock', resource_id=TextBlockFactory(user=user).id)
    ResourceFactory(casebook=casebook, ordinals=[1, 5], resource_type='Case', resource_id=CaseFactory().id)
    ResourceFactory(casebook=casebook, ordinals=[1, 6], resource_type='Default', resource_id=DefaultFactory(user=user).id)
    return casebook


@pytest.fixture
def capapi_mock(requests_mock):
    """
        Mock responses for queries run by CAP import functions.
    """
    # mock citation search results
    requests_mock.get('/v1/cases/', json={
        "count": 2,
        "results": [
            {
                "id": 1,
                "name_abbreviation": "1-800 Contacts, Inc. v. Lens.Com, Inc.",
                "citations": [
                    {
                        "cite": "722 F.3d 1229",
                        "type": "official"
                    }
                ],
                "decision_date": "2013-07-16",
            },
            {
                "id": 2,
                "name_abbreviation": "1-800 Contacts, Inc. v. Lens.Com, Inc.",
                "citations": [
                    {
                        "cite": "722 F.3d 1229",
                        "type": "official"
                    }
                ],
                "decision_date": "2013-07-16",
            },
        ]})
    # mock case detail results
    requests_mock.get('/v1/cases/12345/', json={
        "id": 12345,
        "name": "1-800 CONTACTS, INC., Plaintiff-Appellant/Cross-Appellee, v. LENS.COM, INC.",
        "name_abbreviation": "1-800 Contacts, Inc. v. Lens.Com, Inc.",
        "decision_date": "2013-07-16",
        "docket_number": "Nos. 11-4114, 11-4204, 12-4022",
        "citations": [
            {
                "cite": "722 F.3d 1229",
                "type": "official"
            }
        ],
        "court": {
            "name_abbreviation": "10th Cir.",
            "name": "United States Court of Appeals for the Tenth Circuit",
            "id": 8771
        },
        "casebody": {
            "data": """
                <section class="casebody" data-case-id="32044132252420_0111" data-firstpage="1229" data-lastpage="1257">
                    <section class="head-matter">
                        <h4 class="parties" id="b1241-8">1-800 CONTACTS, INC., Plaintiff-Appellant/Cross-Appellee, v. LENS.COM, INC.</h4>
                        <p class="attorneys" id="b1245-28"><a class="page-label">*1233</a>Mark A. Miller, Holland &amp; Hart LLP</p>
                        <p class="attorneys" id="b1246-4">Scott R. Ryther, Phillips Ryther <em>&amp; </em>Winchester</p>
                    </section>
                    <article class="opinion" data-type="majority">
                        <p class="author" id="b1246-6">HARTZ, Circuit Judge.</p>
                        <p id="b1246-7">The Lanham Act, 15 U.S.C. §§ 1051-1127 ...</p>
                    </article>
                </section>
            """,
            "status": "ok"
        }
    })


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

    content = response.content.decode()
    if content_includes:
        if isinstance(content_includes, str):
            content_includes = [content_includes]
        for content_include in content_includes:
            assert content_include in content
    if content_excludes:
        if isinstance(content_excludes, str):
            content_excludes = [content_excludes]
        for content_exclude in content_excludes:
            assert content_exclude not in content


@pytest.fixture(autouse=True)
def inject_helpers(doctest_namespace):
    doctest_namespace["check_response"] = check_response
    doctest_namespace["reverse"] = reverse
