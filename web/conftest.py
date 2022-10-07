import inspect
import os
import re
from collections import defaultdict
from contextlib import contextmanager
from datetime import datetime
from distutils.sysconfig import get_python_lib
from test.test_helpers import dump_casebook_outline

import factory
import pytest
from django.conf import settings
from django.db import connections
from django.db.backends import utils as django_db_utils
from django.db.backends.base.base import BaseDatabaseWrapper
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from requests_mock import ANY

from main.models import (
    Casebook,
    CasebookEditLog,
    CommonTitle,
    ContentAnnotation,
    ContentCollaborator,
    ContentNode,
    LegalDocument,
    LegalDocumentSource,
    Link,
    LiveSettings,
    Resource,
    Section,
    TextBlock,
    User,
)
from main.utils import re_split_offsets

# This file defines test fixtures available to all tests.
# To see available fixtures run pytest --fixtures

# Allow setup of live server test cases; see https://github.com/microsoft/playwright-python/issues/439
os.environ.setdefault("DJANGO_ALLOW_ASYNC_UNSAFE", "true")


### pytest configuration ###


def pytest_addoption(parser):
    """
    Custom command line options.
    """
    parser.addoption(
        "--write-files",
        default=False,
        action="store_true",
        help="Tests that compare to files on disk should instead update those files",
    )


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
    snake_case_name = re.sub(
        "((?<=[a-z0-9])[A-Z]|(?!^)[A-Z](?=[a-z]))", r"_\1", cls.__name__
    ).lower()

    @pytest.fixture
    def factory_fixture(db):
        return cls

    @pytest.fixture
    def instance_fixture(db):
        return cls()

    globals()[snake_case_name] = factory_fixture
    globals()[snake_case_name.rsplit("_factory", 1)[0]] = instance_fixture

    return cls


### model factories ###


@register_factory
class UserFactory(factory.DjangoModelFactory):
    class Meta:
        model = User

    email_address = factory.Sequence(lambda n: f"user{n}@example.com")
    attribution = factory.Sequence(lambda n: f"Some User {n}")
    affiliation = factory.Sequence(lambda n: f"Affiliation {n}")
    is_active = True


@register_factory
class UnconfirmedUserFactory(UserFactory):
    is_active = False


@register_factory
class VerifiedProfessorFactory(UserFactory):
    verified_professor = True
    professor_verification_requested = True


@register_factory
class AdminUserFactory(UserFactory):
    attribution = "Admin"
    is_staff = True
    is_superuser = True


@register_factory
class ContentNodeFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentNode

    created_at = factory.LazyFunction(timezone.now)
    ordinals = []
    display_ordinals = []
    does_display_ordinals = True
    provenance = []


@register_factory
class CasebookFactory(factory.DjangoModelFactory):
    class Meta:
        model = Casebook

    created_at = factory.LazyFunction(timezone.now)
    contentcollaborator_set = factory.RelatedFactory(
        "conftest.ContentCollaboratorFactory", "casebook", can_edit=True
    )
    title = factory.Sequence(lambda n: f"Some Title {n}")
    state = Casebook.LifeCycle.PUBLISHED.value


@register_factory
class CasebookEditLogFactory(factory.DjangoModelFactory):
    class Meta:
        model = CasebookEditLog

    casebook = factory.SubFactory(CasebookFactory)
    entry_date = factory.LazyFunction(timezone.now)
    change = CasebookEditLog.ChangeType.ORIGINAL_PUBLISH.value
    content = None


@register_factory
class PrivateCasebookFactory(CasebookFactory):
    state = Casebook.LifeCycle.PRIVATELY_EDITING.value
    contentcollaborator_set = factory.RelatedFactory(
        "conftest.ContentCollaboratorFactory", "casebook", can_edit=True
    )


@register_factory
class SectionFactory(ContentNodeFactory):
    class Meta:
        model = Section

    casebook = factory.SubFactory(CasebookFactory)
    ordinals = [1]
    display_ordinals = [1]
    title = factory.Sequence(lambda n: f"Some Section {n}")


@register_factory
class ContentCollaboratorFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentCollaborator

    user = factory.SubFactory(UserFactory, verified_professor=True)
    casebook = factory.SubFactory(CasebookFactory)
    has_attribution = True
    can_edit = True


@register_factory
class LinkFactory(factory.DjangoModelFactory):
    class Meta:
        model = Link

    name = factory.Sequence(lambda n: f"Some Link Name {n}")
    description = factory.Sequence(lambda n: f"Some Link Description {n}")
    url = factory.Sequence(lambda n: f"https://example.com/{n}")
    public = True


@register_factory
class TextBlockFactory(factory.DjangoModelFactory):
    class Meta:
        model = TextBlock

    name = factory.Sequence(lambda n: f"Some TextBlock Name {n}")
    description = factory.Sequence(lambda n: f"Some TextBlock Description {n}")
    content = factory.Sequence(lambda n: f"Some TextBlock Content {n}")


@register_factory
class CommonTitleFactory(factory.DjangoModelFactory):
    class Meta:
        model = CommonTitle

    name = factory.Sequence(lambda n: f"Some Series Name {n}")
    public_url = factory.Sequence(lambda n: f"Some Series URL {n}")
    current = factory.SubFactory(CasebookFactory)


class MockSourceAPI:
    details = {
        "name": "Test",
        "short_description": "The testing api mocks data",
        "long_description": "The ",
        "link": "https://www.govinfo.gov/app/collection/uscode",
    }

    @staticmethod
    def search(search_params):
        return [
            {
                "fullName": "Test Result 1",
                "shortName": "Test 1",
                "fullCitations": "1 USC § 1",
                "shortCitations": "1 USC § 1",
                "effectiveDate": datetime(1901, 1, 1),
                "url": "https://opencasebook.org/legal_doc/1",
                "id": 0,
            },
            {
                "fullName": "Test Result 2",
                "shortName": "Test 2",
                "fullCitations": "1 USC § 2",
                "shortCitations": "1 USC § 2",
                "effectiveDate": datetime(1901, 1, 1),
                "url": "https://opencasebook.org/legal_doc/1",
                "id": 1,
            },
            {
                "fullName": "Test Result 3",
                "shortName": "Test 3",
                "fullCitations": "1 USC § 3",
                "shortCitations": "1 USC § 3",
                "effectiveDate": datetime(1901, 1, 1),
                "url": "https://opencasebook.org/legal_doc/1",
                "id": 2,
            },
        ]

    @staticmethod
    def pull(legal_doc_source, id):
        code = LegalDocument(
            source=legal_doc_source,
            name="Test Doc 1",
            doc_class="Code",
            citations=["1 USC § 1"],
            effective_date=datetime(1901, 1, 1),
            publication_date=datetime(1999, 1, 1),
            updated_date=datetime.now(),
            source_ref=id,
            content="Test Doc 1 Content",
            metadata={},
        )
        return code

    @staticmethod
    def header_template(legal_document):
        return "empty_header.html"


LegalDocumentSource.register_api(MockSourceAPI)


@register_factory
class LegalDocumentSourceFactory(factory.DjangoModelFactory):
    class Meta:
        model = LegalDocumentSource

    name = "Test"
    search_class = "Test"
    date_added = datetime(1900, 1, 1)
    last_updated = datetime(1902, 1, 1)


@register_factory
class LegalDocumentFactory(factory.DjangoModelFactory):
    class Meta:
        model = LegalDocument

    source = factory.SubFactory(LegalDocumentSourceFactory)
    name = factory.Sequence(lambda n: f"Legal Doc {n}")
    citations = ["Adventures in criminality, 1 Fake 1, (2001)"]
    effective_date = datetime(1900, 1, 1)
    publication_date = datetime(1901, 1, 1)
    updated_date = datetime(1902, 1, 1)
    source_ref = factory.Sequence(lambda n: {"id": n})
    content = factory.Sequence(lambda n: f"Dubious legal claim {n}")
    metadata = {}


@register_factory
class ResourceFactory(ContentNodeFactory):
    class Meta:
        model = Resource
        exclude = ("resource",)

    casebook = factory.SubFactory(CasebookFactory)
    resource_type = "LegalDocument"

    @factory.lazy_attribute
    def resource(self):
        if self.resource_type == "LegalDocument":
            return LegalDocumentFactory()
        elif self.resource_type == "Link":
            return LinkFactory()
        else:
            return TextBlockFactory()

    does_display_ordinals = True

    @factory.post_generation
    def show_ordinals(obj, create, extracted, **kwargs):
        obj.display_ordinals = obj.ordinals

    resource_id = factory.SelfAttribute("resource.id")
    title = factory.LazyAttribute(lambda o: o.resource.get_name())


@register_factory
class ContentAnnotationFactory(factory.DjangoModelFactory):
    class Meta:
        model = ContentAnnotation

    kind = "highlight"
    global_start_offset = 0
    global_end_offset = 10


@register_factory
class PublishedAnnotationFactory(ContentAnnotationFactory):
    resource = factory.SubFactory(ResourceFactory)


@register_factory
class PrivateAnnotationFactory(ContentAnnotationFactory):
    resource = factory.SubFactory(
        ResourceFactory, casebook=factory.SubFactory(PrivateCasebookFactory)
    )


@register_factory
class LiveSettingsFactory(factory.DjangoModelFactory):
    class Meta:
        model = LiveSettings

    prevent_exports = False
    export_average_rate = 0
    export_last_minute_updated = 0
    enable_printable_html_export = False


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
    c_1 = casebook_factory(provenance=[root.id])
    c_2 = casebook_factory(provenance=[root.id])
    c_1_1 = casebook_factory(provenance=c_1.provenance + [c_1.id])
    c_1_2 = casebook_factory(provenance=c_1.provenance + [c_1.id])
    return [root, c_1, c_2, c_1_1, c_1_2]


@pytest.fixture
def annotations_factory(db):
    """
    Return a factory function that makes annotated casebooks from brackets in HTML. Example:

    >>> _, annotations_factory = [getfixture(f) for f in ['reset_sequences', 'annotations_factory']]
    >>> casebook, resource = annotations_factory('LegalDocument', '<p>[replace]This[/replace] [highlight]is[/highlight] [elide]a[/elide] [note]case[/note].</p>')
    >>> assert dump_casebook_outline(casebook) == [
    ...       'Casebook<1>: Some Title 0',
    ...       ' Section<1>: Some Section 0',
    ...       '  ContentNode<2> -> LegalDocument<1>: Legal Doc 0',
    ...       '   ContentAnnotation<1>: replace 0-4',
    ...       '   ContentAnnotation<2>: highlight 5-7',
    ...       '   ContentAnnotation<3>: elide 8-9',
    ...       '   ContentAnnotation<4>: note 10-14'
    ... ]
    """

    def factory(resource_type, html, casebook=None, ordinals=None):
        # create casebook, resource, resource_target, and annotations
        if not casebook:
            casebook = CasebookFactory()
            SectionFactory(casebook=casebook, ordinals=[1], display_ordinals=[1])
            ordinals = [1, 1]
        resource_target = {"TextBlock": TextBlockFactory, "LegalDocument": LegalDocumentFactory}[
            resource_type
        ](content=html)
        resource_type = resource_type
        resource = ResourceFactory(
            casebook=casebook,
            ordinals=ordinals,
            display_ordinals=ordinals,
            resource_type=resource_type,
            resource=resource_target,
        )

        # retrieve the processed, cleansed html of the saved resource
        processed_html = resource.resource.content

        # strip html tags, break apart the text, and get annotation brackets and offsets
        text = re.sub(r"<[^>]+?>", "", processed_html)
        html_strs, annotation_offsets, annotation_strs = re_split_offsets(r"\[/?.+?\]", text)

        # resave the resource's content with the annotating brackets stripped
        content = re.sub(r"\[.*?\]", "", processed_html)
        resource.resource.content = content
        resource.resource.save()

        # create each annotation. to support overlapping annotations, pop off each starting annotation and then find
        # the nearest ending annotation:
        annotations = list(zip(annotation_strs, annotation_offsets))
        while annotations:
            annotation_str, annotation_offset = annotations.pop(0)
            kind, content = (annotation_str[1:-1].split(" ", 1) + [None])[:2]
            closing_annotation_str = f"[/{kind}]"
            try:
                closing_index = next(
                    i
                    for i in range(len(annotations))
                    if annotations[i][0] == closing_annotation_str
                )
            except StopIteration:
                raise Exception(f"Closing annotation {closing_annotation_str} not found.")
            _, closing_annotation_offset = annotations.pop(closing_index)
            ContentAnnotationFactory(
                resource=resource,
                kind=kind,
                content=content,
                global_start_offset=annotation_offset,
                global_end_offset=closing_annotation_offset,
            )

        return casebook, resource

    return factory


@pytest.fixture
def full_casebook_parts_factory(db):
    """
    Create:
        - owner
        - casebook
            - section
                - resource -> textblock
                - resource -> legaldocument
                    - annotation
                    - annotation
                - resource -> link
                - section
                     - resource -> textblock
                     - resource -> legaldocument
                         - annotation
                         - annotation
                     - resource -> link
            - section
    """

    def factory(state=Casebook.LifeCycle.PUBLISHED.value, user=None):
        if not user:
            user = UserFactory()
        casebook = CasebookFactory(contentcollaborator_set__user=user, state=state)
        _ = CasebookEditLogFactory(casebook=casebook)
        s_1 = SectionFactory(casebook=casebook, ordinals=[1], display_ordinals=[1])
        r_1_1 = ResourceFactory(
            casebook=casebook, ordinals=[1, 1], display_ordinals=[1, 1], resource_type="TextBlock"
        )
        r_1_2 = legaldocument_resource = ResourceFactory(
            casebook=casebook,
            ordinals=[1, 2],
            display_ordinals=[1, 2],
            resource_type="LegalDocument",
        )
        ContentAnnotationFactory(resource=legaldocument_resource)
        ContentAnnotationFactory(resource=legaldocument_resource, kind="elide")
        r_1_3 = ResourceFactory(
            casebook=casebook, ordinals=[1, 3], display_ordinals=[1, 3], resource_type="Link"
        )
        s_1_4 = SectionFactory(casebook=casebook, ordinals=[1, 4], display_ordinals=[1, 4])
        r_1_4_1 = ResourceFactory(
            casebook=casebook,
            ordinals=[1, 4, 1],
            display_ordinals=[1, 4, 1],
            resource_type="TextBlock",
        )
        r_1_4_2 = legaldocument_resource = ResourceFactory(
            casebook=casebook,
            ordinals=[1, 4, 2],
            display_ordinals=[1, 4, 2],
            resource_type="LegalDocument",
        )
        ContentAnnotationFactory(resource=legaldocument_resource, kind="note")
        ContentAnnotationFactory(resource=legaldocument_resource, kind="replace")
        r_1_4_3 = ResourceFactory(
            casebook=casebook, ordinals=[1, 4, 3], display_ordinals=[1, 4, 3], resource_type="Link"
        )
        s_2 = SectionFactory(casebook=casebook, ordinals=[2], display_ordinals=[2])
        return [casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2]

    return factory


@pytest.fixture
def full_casebook_parts(full_casebook_parts_factory):
    return full_casebook_parts_factory()


@pytest.fixture
def full_casebook(full_casebook_parts):
    return full_casebook_parts[0]


@pytest.fixture
def full_private_casebook(full_casebook_parts_factory):
    """
    The same as full_casebook, except private

    >>> private, published = [getfixture(f) for f in ['full_private_casebook', 'full_casebook']]
    >>> assert private.is_private and not published.is_private
    >>> assert all(node.is_private for node in private.contents.all())
    """
    return full_casebook_parts_factory(state=Casebook.LifeCycle.PRIVATELY_EDITING.value)[0]


@pytest.fixture
def full_private_casebook_for_verified_prof(full_casebook_parts_factory):
    """
    The same as full_private_casebook, except its author is a verified professor

    >>> [book] = [getfixture(f) for f in ['full_private_casebook_for_verified_prof']]
    >>> [author] = book.attributed_authors
    >>> assert author.verified_professor
    """
    prof = VerifiedProfessorFactory()
    return full_casebook_parts_factory(state=Casebook.LifeCycle.PRIVATELY_EDITING.value, user=prof)[
        0
    ]


@pytest.fixture
def full_casebook_parts_with_prof_only_resource(full_casebook_parts_factory):
    """
    The same as full_casebook, except its author is a verified professor and the second
    resource is professor-only.

    >>> [parts] = [getfixture(f) for f in ['full_casebook_parts_with_prof_only_resource']]
    >>> assert isinstance(parts[3], Resource)
    >>> assert parts[3].is_instructional_material
    """
    prof = VerifiedProfessorFactory()
    parts: list[ContentNode] = full_casebook_parts_factory(user=prof)
    parts[3].is_instructional_material = True
    parts[3].title = "Instructional material"
    parts[3].resource.name = "Instructional material"
    parts[3].resource.content = "This is instructional material"
    parts[3].resource.save()
    parts[3].save()
    return parts


@pytest.fixture
def full_casebook_parts_with_draft(full_casebook_parts_factory):
    """
    The same as full_casebook, except has an in-progress draft

    >>> has_draft, draftless = [getfixture(f) for f in ['full_casebook_with_draft', 'full_casebook']]
    >>> assert has_draft.has_draft
    >>> assert not draftless.has_draft
    >>> assert all(node.has_draft for node in has_draft.contents.all())
    >>> assert has_draft.is_public
    >>> assert has_draft.draft.is_private
    """
    # Use full_casebook_parts_factory instead of the full_casebook fixture
    # so that full_casebook_with_draft and full_casebook are independent objects
    # and can be used within the same test
    (
        casebook,
        s_1,
        r_1_1,
        r_1_2,
        r_1_3,
        s_1_4,
        r_1_4_1,
        r_1_4_2,
        r_1_4_3,
        s_2,
    ) = full_casebook_parts_factory()
    casebook.make_draft()
    return [casebook, s_1, r_1_1, r_1_2, r_1_3, s_1_4, r_1_4_1, r_1_4_2, r_1_4_3, s_2]


@pytest.fixture
def full_casebook_with_draft(full_casebook_parts_with_draft):
    return full_casebook_parts_with_draft[0]


@pytest.fixture
def casebook_sections_factory(casebook_factory, section_factory):
    """
    Factory that returns a casebook plus a set of sections with the given ordinals.
    """

    def factory(*ords):
        casebook = casebook_factory()
        sections_by_ordinal = {}
        for ord in ords:
            sections_by_ordinal[ord] = section_factory(casebook=casebook, ordinals=ord)
        return casebook, sections_by_ordinal

    return factory


@pytest.fixture
def draft_casebook(casebook_factory):
    casebook = casebook_factory()
    draft = casebook.make_draft()
    return draft


@pytest.fixture
def other_user(user_factory):
    """A user who has no relationship to a given casebook."""
    return user_factory()


@pytest.fixture
def legal_doc_source(legal_document_source_factory):
    lds = legal_document_source_factory()
    return lds


@pytest.fixture
def legal_doc(legal_document_factory):
    return legal_document_factory()


@pytest.fixture
def capapi_mock(requests_mock):
    """
    Mock responses for queries run by CAP import functions.
    """
    # mock citation search results
    requests_mock.get(
        "/v1/cases/",
        json={
            "count": 2,
            "results": [
                {
                    "id": 1,
                    "name_abbreviation": "1-800 Contacts, Inc. v. Lens.Com, Inc.",
                    "citations": [{"cite": "722 F.3d 1229", "type": "official"}],
                    "decision_date": "2013-07-16",
                },
                {
                    "id": 2,
                    "name_abbreviation": "1-800 Contacts, Incorporated v. Lens.Com, Incorporated",
                    "citations": [{"cite": "755 F. Supp. 2d 1151", "type": "official"}],
                    "decision_date": "2010-12-14",
                },
            ],
        },
    )
    # mock case detail results
    requests_mock.get(
        "/v1/cases/12345/",
        json={
            "id": 12345,
            "name": "1-800 CONTACTS, INC., Plaintiff-Appellant/Cross-Appellee, v. LENS.COM, INC.",
            "name_abbreviation": "1-800 Contacts, Inc. v. Lens.Com, Inc.",
            "decision_date": "2013-07-16",
            "docket_number": "Nos. 11-4114, 11-4204, 12-4022",
            "citations": [{"cite": "722 F.3d 1229", "type": "official"}],
            "court": {
                "name_abbreviation": "10th Cir.",
                "name": "United States Court of Appeals for the Tenth Circuit",
                "id": 8771,
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
                "status": "ok",
            },
        },
    )


@pytest.fixture(scope="function")
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
                if stack_frame.code_context and not stack_frame.filename.startswith(
                    python_lib_path
                ):
                    return stack_frame
            return None

        def capture_stack(self):
            stack = inspect.stack()
            userland_stack_frame = self.get_userland_stack_frame(stack)

            self.db.queries_log[-1].update(
                {
                    "stack": stack,
                    "userland_stack_frame": userland_stack_frame,
                }
            )

            if userland_stack_frame:
                self.log_message(
                    f"Previous SQL query called by {userland_stack_frame.filename}:{userland_stack_frame.lineno}:\n{userland_stack_frame.code_context[0].rstrip()}"
                )

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

    monkeypatch.setattr(
        BaseDatabaseWrapper,
        "make_debug_cursor",
        lambda self, cursor: TracingDebugWrapper(cursor, self),
    )

    @contextmanager
    def _assert_num_queries(db="default", **expected_counts):
        conn = connections[db]
        with CaptureQueriesContext(conn) as context:
            yield
            query_counts = defaultdict(int)
            for q in context.captured_queries:
                query_type = q["sql"].split(" ", 1)[0].lower()
                if query_type not in ("savepoint", "release", "set", "show"):
                    query_counts[query_type] += 1
            if expected_counts != query_counts:
                msg = f"Unexpected queries: expected {expected_counts}, got {dict(query_counts)}"
                if pytestconfig.getoption("verbose") > 0:
                    msg += "\n\nQueries:\n========\n\n"
                    for q in context.captured_queries:
                        stack_frames = (
                            q["stack"]
                            if pytestconfig.getoption("verbose") > 1
                            else [q["userland_stack_frame"]]
                            if q.get("userland_stack_frame")
                            else []
                        )
                        for stack_frame in stack_frames:
                            msg += f"{stack_frame.filename}:{stack_frame.lineno}:\n{stack_frame.code_context[0].rstrip()}\n"
                        short_sql = re.sub(r"\'.*?\'", "'<str>'", q["sql"], flags=re.DOTALL)
                        msg += f"{short_sql}\n\n"
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


@pytest.fixture
def client():
    """
    A version of the Django test client that allows us to specify a user login for a particular request with an
    `as_user` parameter, like `client.get(url, as_user=user).
    """
    from django.test.client import Client

    session_key = settings.SESSION_COOKIE_NAME

    class UserClient(Client):
        def request(self, *args, **kwargs):
            as_user = kwargs.pop("as_user", None)
            if as_user:
                # If as_user is provided, store the current value of the session cookie, call force_login, and then
                # reset the current value after the request is over.
                previous_session = self.cookies.get(session_key)
                self.force_login(as_user)
                try:
                    return super().request(*args, **kwargs)
                finally:
                    if previous_session:
                        self.cookies[session_key] = previous_session
                    else:
                        self.cookies.pop(session_key)
            else:
                return super().request(*args, **kwargs)

    return UserClient()


@pytest.fixture
def client_with_raise_request_exception():
    """
    Django 3.0 adds an argument to the test client, `raise_request_exception`,
    letting you toggle whether or not exceptions raised during the request
    should also be raised in the test.

    This fixture grabs that feature from https://github.com/django/django/pull/10892,
    for use in testing error pages.
    """
    import django.test.client
    from django.test.client import Client

    class RaiseRequestExceptionClient(Client):
        def __init__(self, enforce_csrf_checks=False, raise_request_exception=True, **defaults):
            super().__init__(**defaults)
            self.handler = django.test.client.ClientHandler(enforce_csrf_checks)
            self.raise_request_exception = raise_request_exception
            self.exc_info = None

        def request(self, **request):
            """
            The master request method. Compose the environment dictionary and pass
            to the handler, return the result of the handler. Assume defaults for
            the query environment, which can be overridden using the arguments to
            the request.
            """
            environ = self._base_environ(**request)

            # Curry a data dictionary into an instance of the template renderer
            # callback function.
            data = {}
            on_template_render = django.test.client.partial(
                django.test.client.store_rendered_templates, data
            )
            signal_uid = f"template-render-{id(request)}"
            django.test.client.signals.template_rendered.connect(
                on_template_render, dispatch_uid=signal_uid
            )
            # Capture exceptions created by the handler.
            exception_uid = "request-exception-{id(request)}"
            django.test.client.got_request_exception.connect(
                self.store_exc_info, dispatch_uid=exception_uid
            )
            try:
                try:
                    response = self.handler(environ)
                except django.test.client.TemplateDoesNotExist as e:
                    # If the view raises an exception, Django will attempt to show
                    # the 500.html template. If that template is not available,
                    # we should ignore the error in favor of re-raising the
                    # underlying exception that caused the 500 error. Any other
                    # template found to be missing during view error handling
                    # should be reported as-is.
                    if e.args != ("500.html",):
                        raise

                # Look for a signalled exception, clear the current context
                # exception data, then re-raise the signalled exception.
                # Also make sure that the signalled exception is cleared from
                # the local cache!
                response.exc_info = self.exc_info
                if self.exc_info:
                    _, exc_value, _ = self.exc_info
                    self.exc_info = None
                    if self.raise_request_exception:
                        raise exc_value

                # Save the client and request that stimulated the response.
                response.client = self
                response.request = request

                # Add any rendered template detail to the response.
                response.templates = data.get("templates", [])
                response.context = data.get("context")

                response.json = django.test.client.partial(self._parse_json, response)

                # Attach the ResolverMatch instance to the response
                response.resolver_match = django.test.client.SimpleLazyObject(
                    lambda: django.test.client.resolve(request["PATH_INFO"])
                )

                # Flatten a single context. Not really necessary anymore thanks to
                # the __getattr__ flattening in ContextList, but has some edge-case
                # backwards-compatibility implications.
                if response.context and len(response.context) == 1:
                    response.context = response.context[0]

                # Update persistent cookie data.
                if response.cookies:
                    self.cookies.update(response.cookies)

                return response
            finally:
                django.test.client.signals.template_rendered.disconnect(dispatch_uid=signal_uid)
                django.test.client.got_request_exception.disconnect(dispatch_uid=exception_uid)

    return RaiseRequestExceptionClient


@pytest.fixture()
def mock_successful_matomo_response(requests_mock):
    requests_mock.get(
        ANY,
        json=[
            {
                "label": "casebooks",
                "nb_visits": 3,
                "idsubdatatable": 1,
                "segment": "",
                "subtable": [
                    {
                        "label": "1-some-title",
                        "nb_visits": 1,
                    },
                    {
                        "label": "2-some-title",
                        "nb_visits": 1,
                    },
                ],
            }
        ],
    )
