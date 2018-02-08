require 'service_test_case'

class MergeDraftIntoPublishedCasebookTest < ServiceTestCase
  scenario 'updates published ordinals to match draft' do
    draft = content_nodes(:draft_casebook_to_merge)
    published = content_nodes(:public_casebook)
    draft_section = content_nodes(:draft_casebook_section_to_merge_1_1)

    assert_not_equal(draft_section.ordinals, draft_section.copy_of.ordinals)

    merge = MergeDraftIntoPublishedCasebook.new(draft, published)

    merge.published_ordinals

    #resource created in published casebook. Can't stub because the stub 
    #won't have the updated record
    resource = draft.resources.where("created_at < ?", draft.created_at).first

    assert_equal(resource.ordinals, resource.copy_of.ordinals)
  end
end