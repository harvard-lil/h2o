require 'application_system_test_case'

feature 'links' do
  # FYI: Links are currently called "Defaults" (???)
  # Public links attr doesn't have existing functionality
  describe 'as an anonymous visitor' do
    before do
      visit '/defaults'
    end

    scenario 'browsing links', solr: true do
      link = defaults(:link_one)
      fill_in 'Keywords', with: link.name
      click_link 'SEARCH'

      assert_content link.name
    end
    scenario 'following links', solr: true do
      skip
      link = defaults(:link_one)

      # not sure what testing following links is
      # because click_link doesn't work b/c no route matches it
      # and if you did visit(link.name) you're doing the work of click
      click_link link.name

    end
  end

  describe 'as a registered user' do

    before do
      user = users(:case_admin)
      sign_in(user)
    end

    scenario 'creating a link', solr: true do
      visit '/'
      click_link 'CREATE'
      click_link 'Link'

      fill_in 'Name', with: 'Name of a new link'
      fill_in 'Url', with: 'https://newlink.com/link'

      find('#default_description').set('This is a short description about a link')

      click_button 'Save'

      assert_content 'Link was successfully created.'
    end

    scenario 'fails without a valid url', solr: true do
      visit '/defaults/new'

      fill_in 'Url', with: 'badurl.com'

      click_button 'Save'

      assert_content 'Url must be an absolute path (it must contain http)'
    end

    scenario 'editing a link', solr: true do
      link = defaults(:admin_link)

      visit "/defaults/#{link.id}/edit"

      fill_in 'Name', with: 'New name'

      click_button 'Save'

      assert_content 'Link was succeessfully updated.'
    end
  end
end
