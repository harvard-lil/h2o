class TextBlock < ActiveRecord::Base

  FORMATS = {
    'text/plain' => 'Plain text',
    'text/html' => 'HTML formatted text',
    'text/xml' => 'XML',
    'text/csv' => 'CSV',
    'application/json' => 'JSON',
    'text/css' => 'CSS',
    'text/javascript' => 'Javascript'
    }

  include H2oModelExtensions
  validates_inclusion_of :format, :in => FORMATS.keys

  extend TaggingExtensions::ClassMethods
  extend PlaylistableExtensions::ClassMethods

  include PlaylistableExtensions::InstanceMethods
  include TaggingExtensions::InstanceMethods
  include AuthUtilities

  acts_as_authorization_object

  acts_as_taggable_on :tags

  # This method should return true if instances of this class are annotatable under the collage system.
  def self.annotatable
    true
  end

  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy
  has_one :metadatum, :as => :classifiable, :dependent => :destroy

  accepts_nested_attributes_for :metadatum,
    :allow_destroy => true,
    :reject_if => :all_blank

  def self.select_options
    self.find(:all).collect{|c|[c.to_s,c.id]}
  end

  def display_name
    name
  end

  alias :to_s :display_name

  searchable do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :description
    boolean :active
    boolean :public
    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :metadatum, :stored => true, :multiple => true
  end

end
