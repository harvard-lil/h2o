class Case < ActiveRecord::Base
  include StandardModelExtensions
  include AnnotatableExtensions
  include Rails.application.routes.url_helpers

  RATINGS_DISPLAY = {
    :collaged => "Annotated",
    :bookmark => "Bookmarked",
    :add => "Added to"
  }

  acts_as_taggable_on :tags

  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_request
  belongs_to :case_jurisdiction
  belongs_to :user
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy
  has_many :defects, :as => :reportable
  has_many :playlist_items, :as => :actual_object

  accepts_nested_attributes_for :case_citations,
    :allow_destroy => true,
    :reject_if => proc { |att| att['volume'].blank? || att['reporter'].blank? || att['page'].blank? }

  accepts_nested_attributes_for :case_docket_numbers,
    :allow_destroy => true,
    :reject_if => proc { |att| att['docket_number'].blank? }

  def display_name
    (short_name.blank?) ? full_name : short_name
  end
  def description
    nil
  end
  def score
    0
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

  searchable do
    text :display_name, :boost => 3.0
    text :indexable_case_citations, :boost => 3.0
    text :clean_content
    text :indexable_case_docket_numbers
    text :case_jurisdiction

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
  end

  after_create :assign_to_h2ocases

  alias :to_s :display_name

  def indexable_case_citations
    self.case_citations.map(&:display_name)
  end
  def indexable_case_docket_numbers
    self.case_docket_numbers.map(&:docket_number)
  end
  def indexable_case_jurisdiction
    self.case_jurisdiction.present? ? self.case_jurisdiction.name : ''
  end

  def clean_content
    self.content.gsub!(/\p{Cc}/, "")
  end

  def bookmark_name
    self.short_name
  end

  def approve!
    self.update_attribute(:public, true)
    Notifier.case_notify_approved(self, self.case_request).deliver if self.case_request.present?
  end

  def self.new_from_xml_file(file)
    cxp = CaseXmlParser.new(file)

    new_case = cxp.xml_to_case_attributes
    cj = CaseJurisdiction.where(name: new_case[:jurisdiction].gsub('.', '')).first
    if cj
      new_case[:case_jurisdiction_id] = cj.id
    end
    new_case.delete(:jurisdiction)
    c = Case.new(new_case)
    c.user = User.where(login: 'h2ocases').first

    c
  end

  def to_tsv
    [self.short_name,
     self.case_citations.first.to_s,
     "https://#{host_and_port}/cases/#{self.id}"].join("\t")
  end

  def barcode
    Rails.cache.fetch("case-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = self.barcode_bookmarked_added
      self.collages.each do |collage|
        barcode_elements << { :type => "collaged",
                              :date => collage.created_at,
                              :title => "Annotated to #{collage.name}",
                              :link => collage_path(collage),
                              :rating => 5 }
      end

      value = barcode_elements.inject(0) { |sum, item| sum + item[:rating] }
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
    self.user = User.where(login: 'h2ocases').first
  end

  def date_check
    if !self.decision_date.blank? && self.decision_date > Date.today
      errors.add(:decision_date,'cannot be in the future')
    end
  end
end
