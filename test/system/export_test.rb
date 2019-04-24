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

    downloaded_path = Timeout::timeout(15) do
      while Dir.empty?(@download_dir) or File.extname(Dir[@download_dir + '/*'].first).include? 'download' do
        # Wait for the file to download
      end
      files = Dir[@download_dir + '/*']
      assert_equal files.length, 1
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
