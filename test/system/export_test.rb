require 'application_system_test_case'

class ExportSystemTest < ApplicationSystemTestCase
  scenario 'exporting a casebook to .docx', js:true do
    export_test casebook_path(content_nodes(:public_casebook)), 'Word', 'test_export_casebook.docx'
  end
  scenario 'exporting a section to .docx', js:true do
    export_test  section_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1)), 'Word', 'test_export_section.docx'
  end
  scenario 'exporting a section to .docx', js:true do
    export_test  resource_path(content_nodes(:public_casebook), content_nodes(:'public_casebook_section_1.1')), 'Word', 'test_export_resource.docx'
  end
  scenario 'exporting a casebook to .pdf', js:true do
    export_test casebook_path(content_nodes(:public_casebook)), 'PDF', 'test_export_casebook.pdf'
  end
  scenario 'exporting a section to .pdf', js:true do
    export_test  section_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1)), 'PDF', 'test_export_section.pdf'
  end
  scenario 'exporting a section to .pdf', js:true do
    export_test  resource_path(content_nodes(:public_casebook), content_nodes(:'public_casebook_section_1.1')), 'PDF', 'test_export_resource.pdf'
  end

  def export_test path, format, file
    sign_in user = users(:verified_student)
    visit path
    click_link 'Export'

    within '#export-modal' do
      assert_content 'Export Casebook'
      select format, from: 'export-format'
      click_link 'Export'
    end

    exported_file_url = evaluate_script('_test_window_urls').last
    downloaded_path = download_file exported_file_url, to: file
    assert_equal File.size?(downloaded_path), File.size?(expected_file_path(file))
    assert_equal Digest::SHA256.file(expected_file_path(file)).hexdigest, Digest::SHA256.file(downloaded_path).hexdigest
  end
end
