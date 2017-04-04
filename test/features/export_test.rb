require 'application_system_test_case'

feature 'exporting' do
  include ActiveJob::TestHelper

  scenario 'exporting a case', js:true do
    sign_in users(:verified_student)
      visit case_path public_case = cases(:public_case_1)

      click_link 'Print'

      assert_content public_case.short_name
      assert_content public_case.content

      select 'DOC', from: 'export_format'

      # TODO: Actual exporting is very hard to test. Should be rebuilt
      assert_enqueued_jobs 1 do
        click_link 'export-form-submit'
        assert_content 'H2O is exporting your content to DOC format.'
        sleep 0.1
      end

      visit root_path
  end

    scenario 'exporting a case', js:true do
      sign_in users(:verified_student)
      visit playlist_path public_playlist = cases(:public_playlist_1)

      click_link 'Print'

      assert_content public_playlist.name

      select 'DOC', from: 'export_format'

      # TODO: Actual exporting is very hard to test. Should be rebuilt
      assert_enqueued_jobs 1 do
        click_link 'export-form-submit'
        assert_content 'H2O is exporting your content to DOC format.'
        sleep 0.1
      end

      visit root_path
  end
end
