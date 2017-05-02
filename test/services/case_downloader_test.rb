require 'application_system_test_case'

class CaseDownloaderTest < ApplicationSystemTestCase
	scenario 'Returns true if successfully creates a new case' do
		current_user = users(:verified_professor)
		previous_number_of_cases = Case.count

		download_case(case_params)

		case_downloader = CaseDownloader.perform(current_user, case_params)

		new_number_of_cases = Case.count
		refute_equal new_number_of_cases, previous_number_of_cases

		assert_equal case_downloader, true
	end

	scenario 'Returns false if creating a case fails and sends a notifier mailer' do
		current_user = users(:verified_professor)
		previous_number_of_cases = Case.count

		download_case(incomplete_case_params)

		case_downloader = CaseDownloader.perform(current_user, incomplete_case_params)

		new_number_of_cases = Case.count
		assert_equal new_number_of_cases, previous_number_of_cases

		assert_equal case_downloader, false

		mail = ActionMailer::Base.deliveries.last

		assert_equal H2o::Application.config.admin_email, mail['to'].to_s
	end
end