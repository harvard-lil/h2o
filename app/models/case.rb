require 'tagging_extensions'

class Case < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods
  include TaggingExtensions::InstanceMethods
  
  acts_as_taggable_on :tags

  # This method should return true if instances of this class are annotatable under the collage system.
  def self.annotatable
    true
  end

  has_many :case_citations
  has_many :case_docket_numbers
  belongs_to :case_jurisdiction
  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy

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

end
