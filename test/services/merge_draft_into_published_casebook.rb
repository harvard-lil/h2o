require 'service_test_case'

class MergeDraftIntoPublishedCasebookTest < ServiceTestCase
  before do 
    @draft = content_nodes(:draft_merge_casebook)
    @published = content_nodes(:published_casebook)
    @merge = MergeDraftIntoPublishedCasebook.new(@draft, @published)
  end

  scenario 'updates published ordinals to match draft' do
    draft_section = content_nodes(:draft_merge_section_2_1)
    assert_not_equal(draft_section.ordinals, draft_section.copy_of.ordinals)

    @merge.published_ordinals

    #resource created in published casebook. Canƒ't stub because the stub 
    #won't have the updated record
    resource = @draft.resources.where("created_at < ?", @draft.created_at).first
    assert_equal(resource.ordinals, resource.copy_of.ordinals)
  end

  scenario 'adds newly created resources to published casebook' do
    skip
    assert_not_equal(@draft.resources.count, @published.resources.count)

    @merge.new_resources

    assert_equal(@draft.resources.count, @published.resources.count)
  end
end