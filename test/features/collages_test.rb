require 'application_system_test_case'

class CollageSystemTest < ApplicationSystemTestCase
  describe 'as an anonymous user' do
    scenario 'browsing collages', solr: true do
      visit collages_path
      assert_content collages(:collage_one).name
      assert_no_content collages(:private_collage_1).name
    end
  end

  scenario 'delete a collage', solr: true, js: true do
    collage_to_delete = collages :private_collage_1
    sign_in collage_to_delete.user
    visit user_path collage_to_delete.user

    assert_content collage_to_delete.name
    within "\#listitem_collage#{collage_to_delete.id}" do
      click_link 'DELETE'
    end
    assert_content 'Are you sure you want to delete this item?'
    click_link 'YES'
    click_link 'YES'

    assert_no_content collage_to_delete.name
    visit user_path collage_to_delete.user
    assert_no_content collage_to_delete.name

    collage_undeletable = collages :collage_one
    assert_content collage_undeletable.name
    within "\#listitem_collage#{collage_undeletable.id}" do
      click_link 'DELETE'
    end
    assert_content 'Are you sure you want to delete this item?'
    click_link 'YES'
    click_link 'YES'

    assert_content collage_undeletable.name
    visit user_path collage_undeletable.user
    assert_content collage_undeletable.name
  end
end
