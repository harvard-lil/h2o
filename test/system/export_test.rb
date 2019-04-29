require 'application_system_test_case'
require 'tmpdir'
require 'fileutils'
require 'timeout'
require 'zip'
require 'pretty_diffs'

class ExportSystemTest < ApplicationSystemTestCase

  include PrettyDiffs

  DEFAULT_DOWNLOAD_DIR = H2o::Test::Helpers::Drivers.download_path
  @download_dir

  def setup
    super
    @download_dir = Dir.mktmpdir
    page.driver.browser.download_path = @download_dir
  end

  def teardown
    super
    FileUtils.cp_r(@download_dir + '/.', DEFAULT_DOWNLOAD_DIR)
    FileUtils.remove_entry @download_dir
    page.driver.browser.download_path = DEFAULT_DOWNLOAD_DIR
  end

  scenario 'exporting a casebook to .docx without annotations', js:true do
    export_test casebook_path(content_nodes(:public_casebook)), 'Word', 'test_export_casebook.docx', false
  end
  scenario 'exporting a section to .docx without annotations', js:true do
    export_test  section_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1)), 'Word', 'test_export_section.docx', false
  end
  scenario 'exporting a resource to .docx without annotations', js:true do
    export_test  resource_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1_1)), 'Word', 'test_export_resource.docx', false
  end
  scenario 'exporting a casebook to .docx with annotations', js:true do
    export_test casebook_path(content_nodes(:public_annotated_casebook)), 'Word', 'test_export_casebook_annotated.docx', true
  end
  scenario 'exporting a section to .docx with annotations', js:true do
    export_test section_path(content_nodes(:public_annotated_casebook), content_nodes(:public_annotated_casebook_section_1)), 'Word', 'test_export_section_annotated.docx', true
  end
  scenario 'exporting a resource to .docx with annotations', js:true do
    export_test resource_path(content_nodes(:public_annotated_casebook), content_nodes(:public_annotated_casebook_section_1_1)), 'Word', 'test_export_resource_annotated.docx', true
  end

  def export_test path, format, file, include_annotations
    sign_in user = users(:verified_student)
    visit path

    if include_annotations
      click_link 'Export'
      click_button 'Without annotations'
    else
      click_link 'Export'
    end
    downloaded_path = Timeout::timeout(15) do
      while Dir.empty?(@download_dir) or Dir[@download_dir + '/*'].any? { |file| File.extname(file).include? 'download'} do
        # Wait for the file to download
      end
      files = Dir[@download_dir + '/*']
      assert_equal 1, files.length
      files.first
    end

    if format == 'Word'
      Zip::File.open(expected_file_path(file)) do |expected_docx|
        Zip::File.open(downloaded_path).each do |downloaded_file|
          expected_file = expected_docx.glob(Regexp.escape(downloaded_file.name)).first
          assert_equal expected_file.get_input_stream.read, downloaded_file.get_input_stream.read
        end
      end
    else
      assert_equal File.size?(expected_file_path(file)), File.size?(downloaded_path)
      assert_equal Digest::SHA256.file(expected_file_path(file)).hexdigest, Digest::SHA256.file(downloaded_path).hexdigest
    end
  end
end
