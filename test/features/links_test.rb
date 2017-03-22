require "test_helper"

feature 'links' do
  # FYI: Links are currently called "Defaults" (???)
  describe 'as an anonymous visitor' do
    scenario 'browsing links' do
      # search for links already added to the site
      # can't see private links
    end
    scenario 'following links' do

    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and viewing links' do
      # DRY stuff from above
      # can see prvate links that belong to user
    end
    scenario 'creating a link' do

    end
    scenario 'editing a link' do

    end
  end
end
