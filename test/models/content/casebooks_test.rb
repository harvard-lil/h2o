require 'service_test_case'

class Content::CasebooksTest < ServiceTestCase
  scenario 'Deleting a section deletes its unpublished revisions' do
    draft = content_nodes(:draft_merge_casebook)

    assert_equal(4, draft.unpublished_revisions.count)
    draft.destroy

    assert_equal(0, draft.unpublished_revisions.count)
  end
end
