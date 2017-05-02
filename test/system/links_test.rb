require 'application_system_test_case'

class LinkSystemTest < ApplicationSystemTestCase
  # FYI: Links are currently called "Defaults" (???)
  # Public links attr doesn't have existing functionality
  describe 'as an anonymous visitor' do
    before do
      visit defaults_path
    end

    scenario 'browsing links', solr: true do
      link = defaults(:link_one)
      fill_in 'Keywords', with: link.name
      click_link 'SEARCH'

      assert_content link.name
    end
    scenario 'following links', solr: true do
      link = defaults(:link_one)

      # This helper catches the routing error and asserts on the resulting URL (even though it didn't load). This could also be tested natively by Phantom, but this way works fine
      assert_links_to link.url do
        click_link link.name
      end
    end
  end

  describe 'as a registered user' do

    before do
      user = users(:case_admin)
      sign_in(user)
    end

    scenario 'creating a link', solr: true do
      visit search_all_path
      click_link 'CREATE'
      click_link 'Link'

      fill_in 'Name', with: 'Name of a new link'
      fill_in 'Url', with: 'https://newlink.com/link'

      find('#default_description').set('This is a short description about a link')

      click_button 'Save'

      assert_content 'Link was successfully created.'
    end

    scenario 'fails without a valid url', solr: true do
      visit new_default_path

      fill_in 'Url', with: 'badurl.com'

      click_button 'Save'

      assert_content 'Url must be an absolute path (it must contain http)'
    end

    scenario 'editing a link', solr: true do
      link = defaults(:admin_link)

      visit edit_default_path link

      fill_in 'Name', with: 'New name'

      click_button 'Save'

      assert_content 'Link was succeessfully updated.'
    end
  end
end
