require 'rubygems'
require 'nokogiri'

class CaseXmlParser
  def initialize(file)
    @doc = Nokogiri::XML(file)
  end

  def xml_to_case_attributes
    {:short_name => @doc.css('ShortName').text,
     :full_name => @doc.css('FullName').text,
     :author => @doc.css('Author').text,
     :decision_date => @doc.css('DecisionDate').text,
     :lawyer_header => @doc.css('LawyerHeader').text,
     :party_header => @doc.css('PartyHeader').text,
     :header_html => @doc.css('HeaderHtml').text,
     :content => extract_content,
     :jurisdiction => @doc.css('Jurisdiction CourtName').text,
     :case_docket_numbers_attributes => extract_case_docket_numbers_from_doc,
     :case_citations_attributes => extract_case_citations_attributes}
  end

  private

  def extract_case_docket_numbers_from_doc
    @doc.css('DocketNumber').inject([]){|arr, dn_element| arr << {:docket_number => dn_element.text}}
  end

  def extract_case_citations_attributes
    @doc.css('Citation').inject([]){|arr, c_element| arr << {:reporter =>  c_element.children.css('Reporter').text,
                                                               :volume => c_element.children.css('Volume').text,
                                                               :page => c_element.children.css('Page').text}}
  end

  def content_tags
    ['HeaderHtml', 'CaseHtml']
  end

  def extract_content
    content_tags.inject('') do |content, tag|
      content += decode_content(@doc.css(tag).text)
    end

  end

  def decode_content(content)
    CGI.unescapeHTML(content).gsub(/[^\x00-\x7F]/,'')
  end
end
