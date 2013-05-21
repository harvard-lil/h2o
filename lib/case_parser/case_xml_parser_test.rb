require 'case_xml_parser'
require 'test/unit'
require 'cgi'

class TestCaseXmlParser <  Test::Unit::TestCase

  def setup
    file = File.open('fixtures/731se2d550.xml')
    @cp = CaseXmlParser.new(file)
  end

  def test_requires_file_param
    assert_instance_of CaseXmlParser, @cp
  end

  def test_should_have_method_xml_to_case_attributes
    cp = CaseXmlParser.new(@file)
    assert_respond_to @cp, :xml_to_case_attributes
  end

  def test_should_return_hash_with_short_name
    assert_equal 'Couple v. Baby Girl', @cp.xml_to_case_attributes[:short_name]

  end

  def test_should_return_short_name_as_full_name
    assert_equal 'Couple v. Baby Girl', @cp.xml_to_case_attributes[:full_name]
  end

  def test_should_return_author
    assert_equal 'Justice KITTREDGE.', @cp.xml_to_case_attributes[:author]
  end

  def test_should_return_decision_date
    assert_equal '2012-08-22', @cp.xml_to_case_attributes[:decision_date]
  end

  def test_should_return_party_header
    assert_match 'Appellants, v. BABY GIRL', @cp.xml_to_case_attributes[:party_header]
  end

  def test_should_return_lawyer_header
    assert_match 'Lesley Ann Sasser and Shannon Phillips Jones', @cp.xml_to_case_attributes[:lawyer_header]
  end

  def test_should_return_header_html
    assert_match 'BABY GIRL, a minor child under the age of fourteen years', @cp.xml_to_case_attributes[:header_html]
  end

  def test_should_return_content
    assert @cp.xml_to_case_attributes[:content].include?('Mark D. Fiddler')
  end

  def test_should_return_jurisdiction
    assert_equal 'Supreme Court of South Carolina.', @cp.xml_to_case_attributes[:jurisdiction]
  end

  def test_should_return_2_docket_numbers
    assert_equal 2, @cp.xml_to_case_attributes[:case_docket_numbers_attributes].count
  end

  def test_should_docket_number_attributes_as_a_hash_with_docket_number
    expected_result = {:docket_number => "No. 27148."}
    assert_equal expected_result, @cp.xml_to_case_attributes[:case_docket_numbers_attributes].first
  end

  def test_should_return_2_citations
    assert_equal 2, @cp.xml_to_case_attributes[:case_citations_attributes].count
  end

  def test_should_return_case_citation_attributes_as_a_hash_with_report_volume_page
    expected_result = {:reporter => 'S.C.', :volume => '398', :page => '625'}
    assert_equal expected_result, @cp.xml_to_case_attributes[:case_citations_attributes].first
  end
end
