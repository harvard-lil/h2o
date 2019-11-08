import inspect
import re
from collections import defaultdict
from contextlib import contextmanager
from datetime import datetime
from distutils.sysconfig import get_python_lib
import pytest
import factory

from django.db import connections
from django.db.backends.base.base import BaseDatabaseWrapper
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from django.db.backends import utils as django_db_utils

from main.models import ContentNode, User, Casebook, Section, Resource, ContentCollaborator, Role, Default, TextBlock, \
    Case, CaseCourt, ContentAnnotation
from main.utils import re_split_offsets

from test_helpers import dump_casebook_outline


# This file defines test fixtures available to all tests.
# To see available fixtures run pytest --fixtures

### internal helpers ###

# functions used within this file to set up fixtures


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

    attribution = factory.Sequence(lambda n: 'Some User %s' % n)
    affiliation = factory.Sequence(lambda n: 'Affiliation %s' % n)
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
    public = True


@register_factory
class PrivateCasebookFactory(CasebookFactory):
    public = False


@register_factory
class DraftCasebookFactory(CasebookFactory):
    public = False
    draft_mode_of_published_casebook=True
    copy_of = factory.SubFactory(CasebookFactory)


@register_factory
class SectionFactory(ContentNodeFactory):
    class Meta:
        model = Section

    casebook = factory.SubFactory(CasebookFactory)
    ordinals = [1]
    title = factory.Sequence(lambda n: 'Some Section %s' % n)


@register_factory
class ResourceFactory(ContentNodeFactory):
    class Meta:
        model = Resource

    casebook = factory.SubFactory(CasebookFactory)
    resource_type = 'Case'
    resource_id = factory.LazyFunction(lambda: CaseFactory().id)


@register_factory
class ContentCollaboratorFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentCollaborator

    user = factory.SubFactory(UserFactory, verified_professor=True)
    content = factory.SubFactory(CasebookFactory)
    role = 'owner'
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
    decision_date = datetime(1900, 1, 1)
    citations = [{'cite': '1 Mass. 1'}, {'cite': '2 Jones 2'}]


@register_factory
class PrivateCaseFactory(CaseFactory):
    public = False


@register_factory
class ContentAnnotationFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentAnnotation

    start_paragraph = 1
    start_offset = 0
    end_offset = 10
    kind = 'highlight'
    global_start_offset = 0
    global_end_offset = 10


### fixture functions ###

# these can be injected on demand with getfixture() in doctests, or as function arguments in test files

@pytest.fixture
def casebook_tree(casebook_factory):
    """
        Return a list of Casebooks representing a version tree like:
            - root
                - c_1
                    - c_1_1
                    - c_1_2
                - c_2
    """
    root = casebook_factory()
    c_1 = casebook_factory(ancestry=str(root.id))
    c_2 = casebook_factory(ancestry=str(root.id))
    c_1_1 = casebook_factory(ancestry="%s/%s" % (c_1.ancestry, c_1.id))
    c_1_2 = casebook_factory(ancestry="%s/%s" % (c_1.ancestry, c_1.id))
    return [root, c_1, c_2, c_1_1, c_1_2]


@pytest.fixture
def admin_user(user_factory):
    user = user_factory(attribution='Admin')
    role, created = Role.objects.get_or_create(name='superadmin')
    user.roles.add(role)
    return user


@pytest.fixture
def annotations_factory(db):
    """
        Return a factory function that makes annotated casebooks from brackets in HTML. Example:

        >>> _, annotations_factory = [getfixture(f) for f in ['reset_sequences', 'annotations_factory']]
        >>> casebook, case = annotations_factory('Case', '<p>[replace]This[/replace] [highlight]is[/highlight] [elide]a[/elide] [note]case[/note].</p>')
        >>> assert dump_casebook_outline(casebook) == [
        ...     'Casebook<1>: Some Title 0',
        ...     ' ContentNode<2> -> Case<1>: Foo Foo0 vs. Bar Bar0',
        ...     '  ContentAnnotation<1>: replace 0-4',
        ...     '  ContentAnnotation<2>: highlight 5-7',
        ...     '  ContentAnnotation<3>: elide 8-9',
        ...     '  ContentAnnotation<4>: note 10-14',
        ... ]
    """
    def factory(resource_type, html):
        # break apart provided html and get annotation brackets and offsets
        content = re.sub(r'\[.*?\]', '', html)  # strip brackets
        html = re.sub(r'<[^>]+?>', '', html)  # strip html tags
        html_strs, annotation_offsets, annotation_strs = re_split_offsets(r'\[/?(?:highlight|elide|note|replace)\]', html)

        # create casebook, resource, resource_target, and annotations
        casebook = CasebookFactory()
        resource_target = {'Case': CaseFactory, 'TextBlock': TextBlockFactory}[resource_type](content=content)
        resource = ResourceFactory(casebook=casebook, ordinals=[1], resource_type=resource_type, resource_id=resource_target.id)
        for i in range(0, len(annotation_strs), 2):
            ContentAnnotationFactory(resource=resource, kind=annotation_strs[i][1:-1], global_start_offset=annotation_offsets[i], global_end_offset=annotation_offsets[i+1])

        return casebook, resource_target
    return factory


@pytest.fixture
def full_casebook_parts(casebook_factory):
    """
        Create:
            - owner
            - casebook
                - section
                    - resource -> textblock
                    - resource -> case
                        - annotation
                        - annotation
                    - resource -> link
                    - section
                         - resource -> textblock
                         - resource -> case
                             - annotation
                             - annotation
                         - resource -> link
                - section
    """
    user = UserFactory()
    casebook = casebook_factory(contentcollaborator_set__user=user)
    s_1 = SectionFactory(casebook=casebook, ordinals=[1])
    r_1_1 = ResourceFactory(casebook=casebook, ordinals=[1, 1], resource_type='TextBlock', resource_id=TextBlockFactory(user=user).id)
    r_1_2 = case_resource = ResourceFactory(casebook=casebook, ordinals=[1, 2], resource_type='Case', resource_id=CaseFactory().id)
    ContentAnnotationFactory(resource=case_resource)
    ContentAnnotationFactory(resource=case_resource, kind='elide')
    r_1_3 = ResourceFactory(casebook=casebook, ordinals=[1, 3], resource_type='Default', resource_id=DefaultFactory(user=user).id)
    s_1_4 = SectionFactory(casebook=casebook,  ordinals=[1, 4])
    r_1_4_1 = ResourceFactory(casebook=casebook, ordinals=[1, 4, 1], resource_type='TextBlock', resource_id=TextBlockFactory(user=user).id)
    r_1_4_2 = case_resource = ResourceFactory(casebook=casebook, ordinals=[1, 4, 2], resource_type='Case', resource_id=CaseFactory().id)
    ContentAnnotationFactory(resource=case_resource, kind='note')
    ContentAnnotationFactory(resource=case_resource, kind='replace')
    r_1_4_3 = ResourceFactory(casebook=casebook, ordinals=[1, 4, 3], resource_type='Default', resource_id=DefaultFactory(user=user).id)
    s_2 = SectionFactory(casebook=casebook, ordinals=[2])
    return [casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2]


@pytest.fixture
def full_casebook(full_casebook_parts):
    return full_casebook_parts[0]


@pytest.fixture
def full_private_casebook(full_casebook):
    """
        The same as full_casebook, except private

        >>> private, published = [getfixture(f) for f in ['full_private_casebook', 'full_casebook']]
        >>> assert private.is_private and not published.is_private
        >>> assert all(node.is_private for node in private.contents.all())
    """
    casebook = full_casebook.clone()
    return casebook

@pytest.fixture
def full_casebook_with_draft(full_casebook):
    """
        The same as full_casebook, except has an in-progress draft

        >>> has_draft, draftless = [getfixture(f) for f in ['full_casebook_with_draft', 'full_casebook']]
        >>> assert has_draft.has_draft and not draftless.has_draft
        >>> assert all(node.has_draft for node in has_draft.contents.all())
        >>> assert has_draft.is_public
        >>> assert has_draft.drafts().is_private
    """
    casebook = full_casebook.clone()
    casebook.public = True
    casebook.save()
    casebook.make_draft()
    return casebook

@pytest.fixture
def user_with_cloneable_casebook(casebook_factory, user_factory):
    """
        Standard casebooks can be cloned.

        >>> user = getfixture('user_with_cloneable_casebook')
        >>> casebook = user.casebooks.first()
        >>> assert casebook.permits_cloning
    """
    user = user_factory()
    casebook_factory(contentcollaborator_set__user=user)
    return user


@pytest.fixture
def user_with_uncloneable_casebook(casebook_factory, user_factory):
    """
        Casebooks that are drafts of already-published casebooks may not
        be cloned.

        >>> user = getfixture('user_with_uncloneable_casebook')
        >>> casebook = user.casebooks.first()
        >>> assert not casebook.permits_cloning
    """
    user = user_factory()
    casebook_factory(
        contentcollaborator_set__user=user,
        draft_mode_of_published_casebook=True
    )
    return user


@pytest.fixture
def user_with_draftable_casebook(casebook_factory, user_factory):
    """
        Already-published casebooks may be edited via the draft mechanism.

        >>> user = getfixture('user_with_draftable_casebook')
        >>> casebook = user.casebooks.first()
        >>> assert casebook.allows_draft_creation_by(user)
    """
    user = user_factory()
    casebook_factory(
        contentcollaborator_set__user=user,
        public=True
    )
    return user


@pytest.fixture
def user_with_undraftable_casebooks(casebook_factory, user_factory):
    """
        Private casebooks may be edited directly; they may not be edited
        via the draft mechanism.

        >>> user = getfixture('user_with_undraftable_casebooks')
        >>> casebook = user.casebooks.first()
        >>> assert not casebook.allows_draft_creation_by(user)

        Casebooks may only have one draft at a time.
        >>> casebook = user.casebooks.last()
        >>> assert not casebook.allows_draft_creation_by(user)
    """
    user = user_factory()
    casebook_factory(
        contentcollaborator_set__user=user,
        public=False
    )
    casebook = casebook_factory(
        contentcollaborator_set__user=user,
        public=True
    )
    casebook.make_draft()
    return user


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
                "name_abbreviation": "1-800 Contacts, Incorporated v. Lens.Com, Incorporated",
                "citations": [
                    {
                        "cite": "755 F. Supp. 2d 1151",
                        "type": "official"
                    }
                ],
                "decision_date": "2010-12-14",
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


@pytest.fixture(scope='function')
def assert_num_queries(pytestconfig, monkeypatch):
    """
        Fixture based on django_assert_num_queries, but modified to specify query type and print the line of code
        that triggered the query.

        Provide a context manager to assert which queries will be run by a block of code. Example:

            def test_foo(assert_num_queries):
                with assert_num_queries(select=1, update=2):
                    # run one select and two updates

        Suggestions for adding this to existing tests: start by running with counts empty:

            with assert_num_queries():

        Run the test as:

            pytest -k test_foo -v

        Ensure that the queries run are as expected, then insert the correct counts based on the error message.
    """
    python_lib_path = get_python_lib()

    class TracingDebugWrapper(django_db_utils.CursorDebugWrapper):
        def log_message(self, message):
            django_db_utils.logger.debug(message)

        def get_userland_stack_frame(self, stack):
            for stack_frame in stack[2:]:
                if stack_frame.code_context and not stack_frame.filename.startswith(python_lib_path):
                    return stack_frame
            return None

        def capture_stack(self):
            stack = inspect.stack()
            userland_stack_frame = self.get_userland_stack_frame(stack)

            self.db.queries_log[-1].update({
                'stack': stack,
                'userland_stack_frame': userland_stack_frame,
            })

            if userland_stack_frame:
                self.log_message("Previous SQL query called by %s:%s:\n%s" % (
                    userland_stack_frame.filename,
                    userland_stack_frame.lineno,
                    userland_stack_frame.code_context[0].rstrip()))

        def execute(self, *args, **kwargs):
            try:
                return super().execute(*args, **kwargs)
            finally:
                self.capture_stack()

        def executemany(self, *args, **kwargs):
            try:
                return super().executemany(*args, **kwargs)
            finally:
                self.capture_stack()

    monkeypatch.setattr(BaseDatabaseWrapper, 'make_debug_cursor', lambda self, cursor: TracingDebugWrapper(cursor, self))

    @contextmanager
    def _assert_num_queries(db='default', **expected_counts):
        conn = connections[db]
        with CaptureQueriesContext(conn) as context:
            yield
            query_counts = defaultdict(int)
            for q in context.captured_queries:
                query_type = q['sql'].split(" ", 1)[0].lower()
                if query_type not in ('savepoint', 'release', 'set', 'show'):
                    query_counts[query_type] += 1
            if expected_counts != query_counts:
                msg = "Unexpected queries: expected %s, got %s" % (expected_counts, dict(query_counts))
                if pytestconfig.getoption('verbose') > 0:
                    msg += '\n\nQueries:\n========\n\n'
                    for q in context.captured_queries:
                        stack_frames = q['stack'] if pytestconfig.getoption("verbose") > 1 else [q['userland_stack_frame']] if q['userland_stack_frame'] else []
                        for stack_frame in stack_frames:
                            msg += "%s:%s:\n%s\n" % (stack_frame.filename, stack_frame.lineno, stack_frame.code_context[0].rstrip())
                        short_sql = re.sub(r'\'.*?\'', "'<str>'", q['sql'], flags=re.DOTALL)
                        msg += "%s\n\n" % short_sql
                else:
                    msg += " (add -v option to show queries, or -v -v to show queries with full stack trace)"
                pytest.fail(msg)

    return _assert_num_queries


@pytest.fixture
def reset_sequences(django_db_reset_sequences):
    """
        Reset database IDs and Factory sequence IDs. Use this if you need to have predictable IDs between runs.
        This fixture must be included first (before other fixtures that use the db).
    """
    for factory_class in globals().values():
        if inspect.isclass(factory_class) and issubclass(factory_class, factory.Factory):
            factory_class.reset_sequence(force=True)
