require 'service_test_case'

class DuplicateCaseCheckerTest < ServiceTestCase
  scenario 'returns array with duplicate cases removed' do
    checked_cases = DuplicateCaseChecker.perform(search_results_with_duplicate)

    assert_equal checked_cases.count, 1
  end

  scenario 'returns array untouched if there are no duplicates' do
    checked_cases = DuplicateCaseChecker.perform(two_search_results)

    assert_equal checked_cases.count, 2
  end
end
