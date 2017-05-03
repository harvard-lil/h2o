require 'application_system_test_case'

class CaseDownloaderTest < ApplicationSystemTestCase
  before do
    @current_user = users(:verified_professor)
  end

  scenario 'Returns true if successfully creates a new case' do
    previous_number_of_cases = Case.count

    import_case_from_cap(case_metadata)
    case_downloader = CaseDownloader.perform(@current_user, case_metadata)
    new_number_of_cases = Case.count
    
    refute_equal new_number_of_cases, previous_number_of_cases
    assert_equal case_downloader, true
  end

  scenario 'Returns false if creating a case fails and sends a notifier mailer' do
    previous_number_of_cases = Case.count

    import_case_from_cap(incomplete_case_metadata)
    case_downloader = CaseDownloader.perform(@current_user, incomplete_case_metadata)
    new_number_of_cases = Case.count
    mail = ActionMailer::Base.deliveries.last
    
    assert_equal new_number_of_cases, previous_number_of_cases
    assert_equal case_downloader, false
    assert_equal H2o::Application.config.admin_email, mail['to'].to_s
  end
end
