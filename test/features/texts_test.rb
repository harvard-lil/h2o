require "test_helper"

feature 'texts' do
  # FYI texts are called TextBlocks
  describe 'as an anonymous user' do
    scenario 'browsing texts' do
      skip
      # public texts are visible
      # non-public texts are not visible
    end
    scenario 'searching for a text' do
      skip
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
      skip
      # DRY stuff from above
      # can see private cases that belong to user
    end
    scenario 'annotating a text', js: true do
      skip
      # can be DRY with cases test?
      # cloning
      # highlighting
      # commenting
      # replacing/removing text
    end
    scenario 'creating a text' do
      skip
    end
  end
end
