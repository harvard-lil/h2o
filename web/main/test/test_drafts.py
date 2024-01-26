from concurrent.futures import ThreadPoolExecutor
from main.models import User, Section, Resource
from django.db import connections

from test.test_helpers import dump_casebook_outline

import pytest


def test_merge_drafts(reset_sequences, full_casebook, assert_num_queries, legal_document_factory):

    elena, john = [
        User(attribution=name, email_address=f"{name}@scotus.gov") for name in ["Elena", "John"]
    ]
    elena.save()
    john.save()
    full_casebook.add_collaborator(elena, has_attribution=True)
    section = full_casebook.contents.first()
    section.provenance = [100]
    section.save()
    original_provenances = [x.provenance for x in full_casebook.contents.all()]
    second_casebook = full_casebook.clone(current_user=john)
    draft = full_casebook.make_draft()

    # Merge draft back into original:
    draft.title = "New Title"
    draft.save()
    Section(casebook=draft, ordinals=[3], title="New Section").save()
    ld = legal_document_factory()
    Resource(
        title="New TextBlock",
        casebook=draft,
        ordinals=[3, 1],
        resource_id=ld.id,
        resource_type="LegalDocument",
    ).save()
    with assert_num_queries(select=10, update=3, insert=4):
        new_casebook = draft.merge_draft()
    assert new_casebook == full_casebook
    expected = [
        "Casebook<1>: New Title",
        " Section<19>: Some Section 0",
        "  ContentNode<20> -> TextBlock<5>: Some TextBlock Name 0",
        "  ContentNode<21> -> LegalDocument<1>: Legal Doc 0",
        "   ContentAnnotation<9>: highlight 0-10",
        "   ContentAnnotation<10>: elide 0-10",
        "  ContentNode<22> -> Link<5>: Some Link Name 0",
        "  Section<23>: Some Section 4",
        "   ContentNode<24> -> TextBlock<6>: Some TextBlock Name 1",
        "   ContentNode<25> -> LegalDocument<2>: Legal Doc 1",
        "    ContentAnnotation<11>: note 0-10",
        "    ContentAnnotation<12>: replace 0-10",
        "   ContentNode<26> -> Link<6>: Some Link Name 1",
        " Section<27>: Some Section 8",
        " Section<28>: New Section",
        "  ContentNode<29> -> LegalDocument<3>: Legal Doc 2",
    ]
    assert dump_casebook_outline(new_casebook) == expected

    # The original copy_of attributes from the published version are preserved:
    full_casebook.refresh_from_db()
    assert original_provenances + [[], []] == [x.provenance for x in full_casebook.contents.all()]

    # Clones of the original casebook have proper attribution
    assert elena in second_casebook.attributed_authors


@pytest.mark.django_db(transaction=True)
def test_duplicative_merge_prevented(full_casebook_with_draft):
    """ Fetch two jobs at the same time in threads and make sure same job isn't returned to both. """
    draft = full_casebook_with_draft.draft

    def attempt_merge(i):
        try:
            draft.merge_draft()
            return True
        except Exception as e:
            return e
        finally:
            for connection in connections.all():
                connection.close()

    with ThreadPoolExecutor(max_workers=2) as e:
        results = e.map(attempt_merge, range(2))

    first, second = list(results)
    assert (first is True and "already being merged" in str(second)) or \
           (second is True and "already being merged" in str(first))
