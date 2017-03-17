require "test_helper"

feature 'cases' do
  describe 'anonymous user' do
    scenario 'reading cases' do
      public_case = cases :public_case_1
      visit case_path(public_case)

      assert_content public_case.short_name
      assert_content public_case.author
      assert_content public_case.content
      assert_content public_case.case_jurisdiction.name
    end
  end
end
