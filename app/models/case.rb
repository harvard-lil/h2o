require 'dropbox_sdk'

class Case < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include StandardModelExtensions::InstanceMethods
  include AnnotatableExtensions
  include AuthUtilities
  include Authorship
  include KarmaRounding

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
  validates_length_of     :short_name,      :in => 1..150, :allow_blank => true, :allow_nil => true
  validates_length_of     :full_name,       :in => 1..500,            :allow_blank => true, :allow_nil => true
  validates_length_of     :party_header,    :in => 1..(10.kilobytes), :allow_blank => true, :allow_nil => true
  validates_length_of     :lawyer_header,   :in => 1..(2.kilobytes),  :allow_blank => true, :allow_nil => true
  validates_length_of     :header_html,     :in => 1..(15.kilobytes), :allow_blank => true, :allow_nil => true
  validates_length_of     :content,         :in => 1..(5.megabytes), :allow_blank => true, :allow_nil => true

  searchable(:include => [:collages, :case_citations]) do # TODO: Perhaps add this back in if needed on template, :case_docket_numbers, :case_jurisdiction]) do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :content
    time :decision_date
    time :created_at
    time :updated_at
    boolean :active
    boolean :public
    integer :karma

    string :author
    string :author_display, :stored => true
    integer :author_id, :stored => true
    # string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :case_citations, :stored => true, :multiple => true
    string :case_docket_numbers, :stored => true, :multiple => true
    string :case_jurisdiction, :stored => true, :multiple => true
  end

  after_create :assign_to_h2ocases

  alias :to_s :display_name

  def bookmark_name
    self.short_name
  end

  def approve!
    self.update_attribute('active', true)
  end
  def can_edit?
    return self.owner? || self.admin? || current_user.has_role?(:case_admin) || current_user.has_role?(:superadmin)
  end

  def self.new_from_xml_file(file)
    cxp = CaseXmlParser.new(file)
    new_case = cxp.xml_to_case_attributes
    cj = CaseJurisdiction.find_by_name(new_case[:jurisdiction].gsub('.', ''))
    if cj
      new_case[:case_jurisdiction_id] = cj.id
    end
    new_case.delete(:jurisdiction)
    Case.new(new_case)
  end

  def to_tsv
    [self.short_name,
     self.case_citations.first.to_s,
     "http://#{host_and_port}/cases/#{self.id}"]
  end

  def self.since_date_and_not_active(options = {})
    self.find(:all, :conditions => ["active = false AND created_at > ?", options[:date]])
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

      value = barcode_elements.inject(0) { |sum, item| sum += self.class::RATINGS[item[:type].to_sym].to_i; sum }
      self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  private
  
  def host_and_port
    host = ActionMailer::Base.default_url_options[:host]
    port = ActionMailer::Base.default_url_options[:port]
    port = port.blank? ? '' : ":#{port}"
    "#{host}#{port}"
  end
  
  def assign_to_h2ocases
    h2ocases = User.find_by_login('h2ocases')

    self.accepts_role!(:owner, h2ocases)
  end

  def date_check
    if ! self.decision_date.blank? && self.decision_date > Date.today
      errors.add(:decision_date,'cannot be in the future')
    end
  end
end
