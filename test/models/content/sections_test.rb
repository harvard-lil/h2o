require 'test_helper'

class Content::SectionsTest < ActiveSupport::TestCase
  it 'Deleting a section deletes its unpublished revisions' do
    draft = content_nodes(:draft_merge_casebook)
    draft_section = content_nodes(:draft_merge_section_1)

    assert_equal(2, draft_section.unpublished_revisions.count)
    draft_section.destroy

    assert_equal(0, draft_section.unpublished_revisions.count)
  end
end
