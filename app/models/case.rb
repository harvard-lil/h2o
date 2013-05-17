class Case < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include StandardModelExtensions::InstanceMethods
  include AnnotatableExtensions
  include AuthUtilities

  include ActionController::UrlWriter

  RATINGS = {
    :collaged => 5,
    :bookmark => 1,
    :add => 3
  }

  acts_as_authorization_object

  acts_as_taggable_on :tags

  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_request
  belongs_to :case_jurisdiction
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy
  has_many :defects, :as => :reportable
  accepts_nested_attributes_for :case_citations,
    :allow_destroy => true,
    :reject_if => proc { |att| att['volume'].blank? || att['reporter'].blank? || att['page'].blank? }

  accepts_nested_attributes_for :case_docket_numbers,
    :allow_destroy => true,
    :reject_if => proc { |att| att['docket_number'].blank? }

  def self.select_options
    self.find(:all).collect{|c|[c.to_s,c.id]}
  end

  def display_name
    (short_name.blank?) ? full_name : short_name
  end

  alias :to_s :display_name
  alias :name :display_name

  validate :date_check

  validates_presence_of   :short_name,      :content
  validates_length_of     :short_name,      :in => 1..150
  validates_length_of     :full_name,       :in => 1..500,            :allow_blank => true
  validates_length_of     :party_header,    :in => 1..(10.kilobytes), :allow_blank => true
  validates_length_of     :lawyer_header,   :in => 1..(2.kilobytes),  :allow_blank => true
  validates_length_of     :header_html,     :in => 1..(15.kilobytes), :allow_blank => true
  validates_length_of     :content,         :in => 1..(5.megabytes)

  searchable(:include => [:tags, :collages, :case_citations]) do # TODO: Perhaps add this back in if needed on template, :case_docket_numbers, :case_jurisdiction]) do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :content
    time :decision_date
    time :created_at
    boolean :active
    boolean :public
    integer :karma

    string :author
    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :case_citations, :stored => true, :multiple => true
    string :case_docket_numbers, :stored => true, :multiple => true
    string :case_jurisdiction, :stored => true, :multiple => true
  end

  alias :to_s :display_name

  def top_ancestors
    self.collages.select { |c| c.ancestry.nil? }
  end

  def bookmark_name
    self.short_name
  end

  def approve!
    self.update_attribute('active', true)
  end

  def self.create_from_xml_upload(file)
    cxp = CaseXmlParser.new(file)
    new_case = cxp.xml_to_case_attributes
    new_case[:case_jurisdiction_id] = CaseJurisdiction.find_by_name(new_case[:jurisdiction].gsub('.', '')).id
    new_case.delete(:jurisdiction)
    Case.create(new_case)
  end

  def self.to_tsv(options = {})
    res = ''
    Case.all.each do |case_obj|
      FasterCSV.generate(res, :col_sep => "\t") {|csv| csv << [case_obj.short_name, case_obj.case_citations.first.to_s]}
    end
    res
  end

  def current_collage
    self.collages.detect{|collage| collage.current?}
  end

  def barcode
    Rails.cache.fetch("case-barcode-#{self.id}") do
      barcode_elements = self.barcode_bookmarked_added
      self.collages.each do |collage|
        barcode_elements << { :type => "collaged",
                              :date => collage.created_at,
                              :title => "Collaged to #{collage.name}",
                              :link => collage_path(collage.id) }
      end
      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  private

  def date_check
    if ! self.decision_date.blank? && self.decision_date > Date.today
      errors.add(:decision_date,'cannot be in the future')
    end
  end
end
