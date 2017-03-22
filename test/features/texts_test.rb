require "test_helper"

feature 'texts' do
  # FYI texts are called TextBlocks
  describe 'as an anonymous user' do
    scenario 'browsing texts' do
      # public texts are visible
      # non-public texts are not visible
    end
    scenario 'searching for a text' do
      # this might take some fiddling with to make Solr play nice
    end
    scenario 'reading a text' do
      # content visible
      # metadata visible
      # annotations are visible
    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and reading cases' do
      # DRY stuff from above
      # can see private cases that belong to user
    end
    scenario 'annotating a text', js: true do
      # can be DRY with cases test?
      # cloning
      # highlighting
      # commenting
      # replacing/removing text
    end
    scenario 'creating a text' do
      sign_in users(:verified_student)

      visit root_path

      # TODO: make this more accessible
      within '#create_all_popup' do
        click_link 'Text'
      end

      assert_content 'Add New Text'

      fill_in 'Name', with: text_name = "Test public text - #{random_token}"
      # TODO: There are two fields with label 'Description'
      # TODO: description replaces '-' with '–'
      fill_in 'text_block[description]', with: text_desc = "Test public description: #{random_token}"
      fill_in 'Content', with: text_content = "Test public content - #{random_token}"

      click_button 'Save'

      assert_content 'Text Block was successfully created'
      assert_content text_name
      assert_text text_desc
      assert_content text_content

      text_path = page.current_path
      sign_out
      visit text_path

      assert_content 'sign in'
      assert_content text_name
    end
    scenario 'creating rich content in a text', js: true do

    end
  end
end
