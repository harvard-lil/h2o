class Case < ApplicationRecord
  store_accessor :opinions, :majority

  include Rails.application.routes.url_helpers

  acts_as_taggable_on :tags

  has_many :casebooks, inverse_of: :resource, class_name: 'Content::Casebook'

  has_many :case_docket_numbers, inverse_of: :case
  belongs_to :case_court, optional: true, inverse_of: :cases
  belongs_to :user, optional: true

  accepts_nested_attributes_for :case_docket_numbers,
    :allow_destroy => true,
    :reject_if => proc { |att| att['docket_number'].blank? }

  accepts_nested_attributes_for :case_court,
    :allow_destroy => true,
    :reject_if => proc { |att| att['name'].blank? || att['abbreviation'].blank? }


  def display_name
    (name_abbreviation.blank?) ? name : name_abbreviation
  end

  def description
    nil
  end

  def title
    name
  end

  def date_year
    decision_date.try :year
  end

  alias :to_s :display_name

  validate :date_check

  validates_presence_of   :name_abbreviation,      :content
  validates_length_of     :name_abbreviation,      :in => 1..150, :allow_blank => true, :allow_nil => true
  validates_length_of     :header_html,            :in => 1..(15.kilobytes), :allow_blank => true, :allow_nil => true
  validates_length_of     :content,                :in => 1..(5.megabytes), :allow_blank => true, :allow_nil => true

  searchable do
    text :name, :boost => 3.0
    text :name_abbreviation
    text :indexable_case_citations, :boost => 3.0
    text :indexable_case_docket_numbers
    text :indexable_case_court
    # text :clean_content

    string :display_name, :stored => true
    string :id, :stored => true
    time :decision_date
    time :created_at
    time :updated_at
    boolean :public

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

  def primary_citation
    if citations && citations.first
      citation_to_s citations.first
    else
      ""
    end
  end

  def indexable_case_citations
    self.citations.map(&method(:citation_to_s)).join(" ")
  end
  def indexable_case_docket_numbers
    self.case_docket_numbers.map(&:docket_number)
  end
  def indexable_case_court
    self.case_court.present? ? self.case_court.name : ''
  end

  def clean_content
    self.content.encode.gsub!(/\p{Cc}/, "")
    # encode needed for cap api import
  end

  def formatted_decision_date
    if self.decision_date.present?
      self.decision_date.strftime("%B %d, %Y")
    end
  end

  def capapi_id=(new_id)
    if new_id != capapi_id
      @capapi = nil
      super new_id
    end
  end

  def capapi
    @capapi ||= Capapi::Case.new(capapi_id) if capapi_id
  end

  def capapi= capapi_case
    if capapi_case
      self.capapi_id = capapi_case.id
      @capapi = capapi_case
    else
      capapi_id = nil
    end
  end

  def self.where_citations_contains citation
    where('citations @> ?', [citation].to_json)
  end

  private

  def date_check
    if !self.decision_date.blank? && self.decision_date > Date.today
      errors.add(:decision_date,'cannot be in the future')
    end
  end
  def citation_to_s citation
    "#{citation['volume']} #{citation['reporter']} #{citation['page']}"
  end
end
