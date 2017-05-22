# == Schema Information
#
# Table name: cases
#
#  id                   :integer          not null, primary key
#  current_opinion      :boolean          default(TRUE)
#  short_name           :string(150)      not null
#  full_name            :string(500)
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
#  user_id              :integer          default(0), not null
#  created_via_import   :boolean          default(FALSE), not null
#

class Case < ApplicationRecord
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
  belongs_to :case_request, optional: true
  belongs_to :case_jurisdiction, optional: true
  belongs_to :user, optional: true
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy
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
    self.content.encode.gsub!(/\p{Cc}/, "")
    # encode needed for cap api import
  end

  def printable_content
    doc = Nokogiri::HTML.parse(self.content)
    PlaylistExportJob.new.convert_h_tags(doc)
    PlaylistExportJob.new.inject_doc_styles(doc)
    doc.xpath("/html/body/*").to_s
  end

  def bookmark_name
    self.short_name
  end

  def approve!
    self.update_attribute(:public, true)
    if self.case_request.present?
      Notifier.case_notify_approved(self, self.case_request).deliver
    end
  end

  def self.new_from_xml_file(file)
    cxp = CaseParser::XmlParser.new(file)

    new_case = cxp.xml_to_case_attributes
    cj = CaseJurisdiction.where(name: new_case[:jurisdiction].gsub('.', '')).first
    if cj
      new_case[:case_jurisdiction_id] = cj.id
    end
    new_case.delete(:jurisdiction)
    c = Case.new(new_case)
    c.user = User.find_by_login 'h2ocases'
    # c.user = User.includes(:roles).where(roles: {name: 'case_admin'}).first

    c
  end

  def version
    1.0
  end

  def to_partial_path
    "cases/court_case"
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
