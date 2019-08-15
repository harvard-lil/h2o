require 'test_helper'

class MergeDraftIntoPublishedCasebookTest < ActiveSupport::TestCase
  before do 
    @draft = content_nodes(:draft_merge_casebook)
    @published = content_nodes(:published_casebook)
    @merge = MergeDraftIntoPublishedCasebook.new(@draft, @published)
  end

  it 'remove deleted resources' do
    assert_equal(4, @published.resources.count)

    @merge.remove_deleted_resources

    assert_equal(3, @published.resources.count)
  end

  it 'updates published ordinals' do
    assert_equal([1, 1], @published.resources.where(resource_id: cases(:public_case_to_annotate).id).first.ordinals)

    @merge.reflow_published_ordinals

    assert_equal([2, 1], @published.resources.where(resource_id: cases(:public_case_to_annotate).id).first.ordinals)
  end

  it 'adds newly created draft resources to published' do
    assert_not_equal(@draft.resources.count, @published.resources.count)

    @merge.add_new_resources

    assert_equal(@draft.resources.count, @published.resources.count)
  end

  it 'merges unpublished revisions into published casebook' do
    assert_equal("Long Prison Term Is Less So Thanks to Regrets by a Judge", @published.resources.where(ordinals: [1]).first.title)
    assert_equal("This is some content.", @published.resources.where(ordinals: [2]).first.resource.content)

    @merge.merge_in_unpublished_revisions

    assert_equal("New title", @published.resources.where(ordinals: [1]).first.title)
    assert_equal("New content", @published.resources.where(ordinals: [2]).first.resource.content)
  end

  it 'adds/merges new and updated annotations' do
    assert_equal(1, @published.resources.where(ordinals: [1]).first.annotations.count)
    assert_equal("published note", @published.resources.where(ordinals: [1]).first.annotations.where(kind: 'note').first.content)

    @merge.new_and_updated_annotations

    assert_equal(2, @published.resources.where(ordinals: [1]).first.annotations.count)
    assert_equal("updated published note", @published.resources.where(ordinals: [1]).first.annotations.where(kind: 'note').first.content)
  end

  it 'removes deleted annotations from published' do
    assert_equal(1, @published.resources.where(ordinals: [2]).first.annotations.count)

    @merge.deleted_annotations

    assert_equal(0, @published.resources.where(ordinals: [2]).first.annotations.count)
  end

  it 'adds, deletes or modifies content collaborators' do
    ## Multiple collaborator functionality doesn't exist yet
    skip
    # assert_equal(2, @published.collaborators.count)
    # assert_equal("student@law.harvard.edu", @published.collaborators.where(role: 'editor').first.user.email_address)
    # @merge.content_collaborators
    # assert_equal(2, @published.collaborators.count)
    # assert_equal("verified_student@example.edu", @published.collaborators.where(role: 'editor').first.user.email_address)
  end

  it 'draft is destroyed after merge finished and published casebook is returned' do
    assert_equal(false, @draft.destroyed?)

    casebook = MergeDraftIntoPublishedCasebook.perform(@draft, @published)

    assert_equal(true, @draft.destroyed?)
    assert_equal(@published, casebook)
  end
end