require 'tagging_extensions'
require 'playlistable_extensions'
require 'annotatable_extensions'

class Case < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include AnnotatableExtensions
  include PlaylistableExtensions
  include AuthUtilities

  acts_as_authorization_object
  
  acts_as_taggable_on :tags

  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_request
  belongs_to :case_jurisdiction
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy

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
    string :author, :stored => true
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

  private

  def date_check
    if ! self.decision_date.blank? && self.decision_date > Date.today
      errors.add(:decision_date,'cannot be in the future')
    end
  end
end
