from test.test_helpers import dump_casebook_outline
from main.models import User, Casebook


def test_clone(reset_sequences, full_casebook, user, assert_num_queries):
    """It should be possible to clone one casebook into another and retain the structure, provenence info, and metadata"""
    # Given an initial casebook like this:
    expected = [
        "Casebook<1>: Some Title 0",
        " Section<1>: Some Section 0",
        "  ContentNode<2> -> TextBlock<1>: Some TextBlock Name 0",
        "  ContentNode<3> -> LegalDocument<1>: Legal Doc 0",
        "   ContentAnnotation<1>: highlight 0-10",
        "   ContentAnnotation<2>: elide 0-10",
        "  ContentNode<4> -> Link<1>: Some Link Name 0",
        "  Section<5>: Some Section 4",
        "   ContentNode<6> -> TextBlock<2>: Some TextBlock Name 1",
        "   ContentNode<7> -> LegalDocument<2>: Legal Doc 1",
        "    ContentAnnotation<3>: note 0-10",
        "    ContentAnnotation<4>: replace 0-10",
        "   ContentNode<8> -> Link<2>: Some Link Name 1",
        " Section<9>: Some Section 8",
    ]

    assert dump_casebook_outline(full_casebook) == expected
    assert user not in set(full_casebook.attributed_authors)

    # Return a cloned casebook like this:
    with assert_num_queries(select=6, insert=11):
        clone = full_casebook.clone(current_user=user)
    expected = [
        "Casebook<2>: Some Title 0",
        " Section<10>: Some Section 0",
        "  ContentNode<11> -> TextBlock<3>: Some TextBlock Name 0",
        "  ContentNode<12> -> LegalDocument<1>: Legal Doc 0",
        "   ContentAnnotation<5>: highlight 0-10",
        "   ContentAnnotation<6>: elide 0-10",
        "  ContentNode<13> -> Link<3>: Some Link Name 0",
        "  Section<14>: Some Section 4",
        "   ContentNode<15> -> TextBlock<4>: Some TextBlock Name 1",
        "   ContentNode<16> -> LegalDocument<2>: Legal Doc 1",
        "    ContentAnnotation<7>: note 0-10",
        "    ContentAnnotation<8>: replace 0-10",
        "   ContentNode<17> -> Link<4>: Some Link Name 1",
        " Section<18>: Some Section 8",
    ]
    assert dump_casebook_outline(clone) == expected
    assert user in set(clone.attributed_authors)
    assert clone.provenance == [full_casebook.id]
    assert clone.state == Casebook.LifeCycle.NEWLY_CLONED.value
    clone_of_clone = clone.clone(current_user=user)
    assert clone_of_clone.provenance == [full_casebook.id, clone.id]
    clone3 = clone_of_clone.clone(current_user=user)
    assert clone3.provenance == [full_casebook.id, clone.id, clone_of_clone.id]


def test_cloning_attribution(full_casebook):
    """Attributions should be preserved when cloning"""
    casebook = full_casebook
    sonya, elena, john = [
        User(attribution=name, email_address=f"{name}@scotus.gov")
        for name in ["Sonya", "Elena", "John"]
    ]
    sonya.save()
    elena.save()
    john.save()
    casebook.add_collaborator(sonya, has_attribution=True)
    casebook.save()
    first_clone = casebook.clone(current_user=elena)
    first_clone.save()
    first_clone.refresh_from_db()
    assert sonya in first_clone.attributed_authors
    assert elena in first_clone.attributed_authors
    assert elena not in casebook.attributed_authors
    second_clone = first_clone.clone(current_user=elena)
    assert sonya in second_clone.originating_authors
    assert elena in second_clone.primary_authors
    assert second_clone.editable_by(elena)
    assert not second_clone.editable_by(sonya)
    casebook.add_collaborator(john, has_attribution=True)
    assert john in casebook.attributed_authors
    assert john in first_clone.attributed_authors
    assert john in second_clone.originating_authors


def test_clone_to(reset_sequences, full_casebook_parts_factory):
    """It should be possible to clone a section or resource from one casebook to another when called"""
    from_casebook = full_casebook_parts_factory()[0]
    to_casebook = full_casebook_parts_factory()[0]
    section = from_casebook.sections[1]
    resource = from_casebook.resources[0]

    # Can append a section or a resource to the end of to_casebook:
    dump_casebook_outline(to_casebook)[-7:]
    section.clone_to(to_casebook)
    dump_casebook_outline(to_casebook)[-7:]
    resource.clone_to(to_casebook)
    dump_casebook_outline(to_casebook)[-7:]
    assert dump_casebook_outline(to_casebook)[-7:] == [
        " Section<19>: Some Section 4",
        "  ContentNode<20> -> TextBlock<5>: Some TextBlock Name 1",
        "  ContentNode<21> -> LegalDocument<2>: Legal Doc 1",
        "   ContentAnnotation<9>: note 0-10",
        "   ContentAnnotation<10>: replace 0-10",
        "  ContentNode<22> -> Link<5>: Some Link Name 1",
        " ContentNode<23> -> TextBlock<6>: Some TextBlock Name 0",
    ]

    # Ordinals should be properly updated:
    assert [node.ordinals for node in list(to_casebook.contents.all())[-5:]] == [
        [3],
        [3, 1],
        [3, 2],
        [3, 3],
        [4],
    ]
