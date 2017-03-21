require "test_helper"

feature 'cases' do
  describe 'as an anonymous user' do
    scenario 'browsing cases' do
      skip
      # public cases are visible
      # non-public cases are not visible
    end
    scenario 'searching for a case' do
      skip
      # this might take some fiddling with to make Solr play nice
    end
    scenario 'reading a case' do
      public_case = cases :public_case_1
      visit case_path(public_case)

      assert_content public_case.short_name
      assert_content public_case.author
      assert_content public_case.content
      assert_content public_case.case_jurisdiction.name

      # annotations are visible
    end
  end
  describe 'as a registered user' do
    scenario 'browsing, searching, and reading cases' do
      skip
      # DRY stuff from above
      # can see private cases that belong to user
    end
    scenario 'annotating a case', js: true do
      skip
      # cloning
      # highlighting
      # commenting
      # replacing/removing text
    end
    scenario 'requesting a case for import' do
      skip
    end
  end
  describe 'as a case administrator' do
    scenario 'viewing case requests' do
      skip
    end
    scenario 'adding a case for a request' do
      skip
    end
    scenario 'rejecting a case request' do
      skip
    end
    scenario 'editing a case' do
      skip
    end
  end
end
