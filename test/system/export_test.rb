require 'application_system_test_case'

class ExportSystemTest < ApplicationSystemTestCase
  scenario 'exporting a casebook to .docx', js:true do
    export_test casebook_path(content_nodes(:public_casebook)), 'Word', 'test_export_casebook.docx'
  end
  scenario 'exporting a section to .docx', js:true do
    export_test  section_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1)), 'Word', 'test_export_section.docx'
  end
  scenario 'exporting a section to .docx', js:true do
    export_test  resource_path(content_nodes(:public_casebook), content_nodes(:'public_casebook_section_1_1')), 'Word', 'test_export_section_2.docx'
  end

  def export_test path, format, file
    sign_in user = users(:verified_student)
    visit path
    click_link 'Export'

    # there must be a better way....
    sleep 30
    downloaded_path = Dir[Rails.root.join 'tmp/downloads/*'].first

    assert_equal File.size?(expected_file_path(file)), File.size?(downloaded_path)
    assert_equal Digest::SHA256.file(expected_file_path(file)).hexdigest, Digest::SHA256.file(downloaded_path).hexdigest
  end
end
