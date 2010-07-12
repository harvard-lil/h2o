require 'tagging_extensions'

class Case < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods
  include TaggingExtensions::InstanceMethods
  include AuthUtilities

  acts_as_authorization_object
  
  acts_as_taggable_on :tags

  before_destroy :deleteable?

  # This method should return true if instances of this class are annotatable under the collage system.
  def self.annotatable
    true
  end

  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_jurisdiction
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy

  accepts_nested_attributes_for :case_citations, 
    :allow_destroy => true, 
    :reject_if => proc { |att| att['volume'].blank? || att['reporter'].blank? || att['page'].blank? }

  accepts_nested_attributes_for :case_docket_numbers, 
    :allow_destroy => true,
    :reject_if => proc { |att| att['docket_number'].blank? }

  accepts_nested_attributes_for :case_jurisdiction,
    :allow_destroy => true,
    :reject_if => proc { |att| att['abbreviation'].blank? || att['name'].blank? }

#  def case_manager?
#    return (current_user.has_role?(:case_manager) || current_user.has_role?(:admin) || self.accepts_role?(:owner, current_user))
#  end

  def self.select_options
    self.find(:all).collect{|c|[c.display_name,c.id]}
  end

  def display_name
    (short_name.blank?) ? full_name : short_name
  end

  validates_presence_of   :short_name, :full_name, :content
  validates_length_of     :short_name,      :in => 1..150
  validates_length_of     :full_name,       :in => 1..500
  validates_length_of     :party_header,    :in => 1..(10.kilobytes), :allow_blank => true
  validates_length_of     :lawyer_header,   :in => 1..(2.kilobytes), :allow_blank => true
  validates_length_of     :header_html,     :in => 1..(15.kilobytes), :allow_blank => true
  validates_length_of     :content,         :in => 1..(5.megabytes)

  def deleteable?
    # Only allow deleting if there haven't been any collages created from this case.
    self.collages.length == 0
  end

  def content_editable?
    # Only allow the content to be edited if there haven't been any collages created from this case.
    self.collages.length == 0
  end

end
