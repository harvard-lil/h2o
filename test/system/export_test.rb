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

  scenario 'exporting a casebook without annotations to .docx', js:true do
    export_test casebook_path(content_nodes(:public_casebook)), 'Word', 'test_export_casebook.docx'
  end
  scenario 'exporting a section without annotations to .docx', js:true do
    export_test  section_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1)), 'Word', 'test_export_section.docx'
  end
  scenario 'exporting a resource without annotations to .docx', js:true do
    export_test  resource_path(content_nodes(:public_casebook), content_nodes(:public_casebook_section_1_1)), 'Word', 'test_export_resource.docx'
  end

  scenario 'exporting an annotated casebook to .docx without annotations', js:true do
    export_test casebook_path(content_nodes(:public_annotated_casebook)), 'Word', 'test_export_annotated_casebook_without_annotations.docx', true
  end
  scenario 'exporting an annotated casebook section to .docx without annotations', js:true do
    export_test section_path(content_nodes(:public_annotated_casebook), content_nodes(:public_annotated_casebook_section_1)), 'Word', 'test_export_annotated_section_without_annotations.docx', true
  end
  scenario 'exporting an annotated casebook resource to .docx without annotations', js:true do
    export_test resource_path(content_nodes(:public_annotated_casebook), content_nodes(:public_annotated_casebook_section_1_1)), 'Word', 'test_export_annotated_resource_without_annotations.docx', true
  end

  scenario 'exporting an annotated casebook to .docx with annotations', js:true do
    export_test casebook_path(content_nodes(:public_annotated_casebook)), 'Word', 'test_export_annotated_casebook_with_annotations.docx', true, true
  end
  scenario 'exporting an annotated casebook section to .docx with annotations', js:true do
    export_test section_path(content_nodes(:public_annotated_casebook), content_nodes(:public_annotated_casebook_section_1)), 'Word', 'test_export_annotated_section_with_annotations.docx', true, true
  end
  scenario 'exporting an annotated casebook resource to .docx with annotations', js:true do
    export_test resource_path(content_nodes(:public_annotated_casebook), content_nodes(:public_annotated_casebook_section_1_1)), 'Word', 'test_export_annotated_resource_with_annotations.docx', true, true
  end

  describe 'export modal appears' do
    before do
      @casebook = content_nodes(:public_annotated_casebook)
      @section = content_nodes(:public_annotated_casebook_section_1)
      @resource = content_nodes(:public_annotated_casebook_section_1_1)
    end

    scenario 'casebook view', js: true do
      visit casebook_path @casebook
      assert_link "Export"
      click_link "Export"
      assert_button "With annotations"
      assert_button "Without annotations"
    end

    scenario 'section view', js: true do
      visit section_path @casebook, @section
      assert_link "Export"
      click_link "Export"
      assert_button "With annotations"
      assert_button "Without annotations" 
    end

    scenario 'resource view', js: true do
      visit resource_path @casebook, @resource
      assert_link "Export"
      click_link "Export"
      assert_button "With annotations"
      assert_button "Without annotations"
    end
  end

  def export_test path, format, file, has_annotations=false, include_annotations=false
    sign_in user = users(:verified_student)
    visit path

    click_link 'Export'
    if has_annotations
      if include_annotations
        click_button 'With annotations'
      else
        click_button 'Without annotations'
      end
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
