# == Schema Information
#
# Table name: cases
#
#  id                   :integer          not null, primary key
#  current_opinion      :boolean          default(TRUE)
#  short_name           :string(150)      not null
#  full_name            :string
#  decision_date        :date
#  author               :string(150)
#  case_jurisdiction_id :integer
#  party_header         :string(10240)
#  lawyer_header        :string(2048)
#  header_html          :string(15360)
#  content              :string(5242880)  not null
#  created_at           :datetime
#  updated_at           :datetime
#  public               :boolean          default(FALSE)
#  case_request_id      :integer
#  karma                :integer
#  pushed_from_id       :integer
#  sent_in_cases_list   :boolean          default(FALSE)
#  user_id              :integer          default(0)
#  created_via_import   :boolean          default(FALSE), not null
#

class Case < ApplicationRecord
  include Rails.application.routes.url_helpers

  acts_as_taggable_on :tags

  has_many :casebooks, inverse_of: :resource, class_name: 'Content::Casebook'

  has_many :case_citations, inverse_of: :case
  has_many :case_docket_numbers, inverse_of: :case
  belongs_to :case_request, optional: true, inverse_of: :case
  belongs_to :case_jurisdiction, optional: true, inverse_of: :cases
  belongs_to :user, optional: true

  accepts_nested_attributes_for :case_citations,
    :allow_destroy => true,
    :reject_if => proc { |att| att['volume'].blank? || att['reporter'].blank? || att['page'].blank? }

  accepts_nested_attributes_for :case_docket_numbers,
    :allow_destroy => true,
    :reject_if => proc { |att| att['docket_number'].blank? }

  accepts_nested_attributes_for :case_jurisdiction,
    :allow_destroy => true,
    :reject_if => proc { |att| att['name'].blank? || att['abbreviation'].blank? }


  def display_name
    (short_name.blank?) ? full_name : short_name
  end
  def description
    nil
  end
  def title
    full_name
  end
  def date_year
    decision_date.try :year
  end
  def score
    0
  end

  alias :to_s :display_name
  alias :name :display_name

  validate :date_check

  validates_presence_of   :short_name,      :content
  validates_length_of     :short_name,      :in => 1..150, :allow_blank => true, :allow_nil => true
  validates_length_of     :party_header,    :in => 1..(10.kilobytes), :allow_blank => true, :allow_nil => true
  validates_length_of     :lawyer_header,   :in => 1..(2.kilobytes),  :allow_blank => true, :allow_nil => true
  validates_length_of     :header_html,     :in => 1..(15.kilobytes), :allow_blank => true, :allow_nil => true
  validates_length_of     :content,         :in => 1..(5.megabytes), :allow_blank => true, :allow_nil => true

  searchable do
    text :full_name, :boost => 3.0
    text :short_name
    text :indexable_case_citations, :boost => 3.0
    text :indexable_case_docket_numbers
    text :indexable_case_jurisdiction
    # text :clean_content

    string :display_name, :stored => true
    string :id, :stored => true
    time :decision_date
    time :created_at
    time :updated_at
    boolean :public
    integer :karma

    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true

    string :klass, :stored => true
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end

    string(:verified_professor, stored: true)
  end
  
  alias :to_s :display_name

  def verified_professor
    # Since we're searching all models together in Sunspot, this field needs to be 
    # created so that all cases will always show up.
    true
  end

  def indexable_case_citations
    self.case_citations.map(&:display_name).join(" ")
  end
  def indexable_case_docket_numbers
    self.case_docket_numbers.map(&:docket_number)
  end
  def indexable_case_jurisdiction
    self.case_jurisdiction.present? ? self.case_jurisdiction.name : ''
  end

  def clean_content
    self.content.encode.gsub!(/\p{Cc}/, "")
    # encode needed for cap api import
  end

  # def self.new_from_xml_file(file)
  #   cxp = CaseParser::XmlParser.new(file)
  #
  #   new_case = cxp.xml_to_case_attributes
  #   cj = CaseJurisdiction.where(name: new_case[:jurisdiction].gsub('.', '')).first
  #   if cj
  #     new_case[:case_jurisdiction_id] = cj.id
  #   end
  #   new_case.delete(:jurisdiction)
  #   c = Case.new(new_case)
  #   # c.user = User.find_by_login 'h2ocases'
  #   c.user = User.includes(:roles).where(roles: {name: 'case_admin'}).first
  #
  #   c
  # end

  def to_partial_path
    "cases/court_case"
  end

  def formatted_decision_date
    if self.decision_date.present?
      self.decision_date.strftime("%B %d, %Y")
    end
  end

  private

  def date_check
    if !self.decision_date.blank? && self.decision_date > Date.today
      errors.add(:decision_date,'cannot be in the future')
    end
  end
end
