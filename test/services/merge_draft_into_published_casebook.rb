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

  scenario 'newly created resources' do
    assert_not_equal(@draft.resources.count, @published.resources.count)

    @merge.new_resources

    assert_equal(@draft.resources.count, @published.resources.count)
  end

  scenario 'unpublished revisions into published casebook' do
    assert_equal("Case of the District Number 2", @published.resources.first.title)

    @merge.unpublished_revisions

    assert_equal("New title", @published.resources.first.title)
  end

  scenario 'unpublished revisions for textblock resource' do
    skip
  end

  scenario 'new and updated annotations' do
  end

  scenario 'deleted annotations' do
  end

  scenario 'content collaborators' do
  end

  scenario 'draft is destroyed after merge finished' do
    # test whole class output
  end
end