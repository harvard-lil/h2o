class TextBlock < ActiveRecord::Base
  include H2oModelExtensions
  include AnnotatableExtensions
  extend TaggingExtensions::ClassMethods
  include PlaylistableExtensions
  include TaggingExtensions::InstanceMethods
  include AuthUtilities

  MIME_TYPES = {
    'text/plain' => 'Plain text',
    'text/html' => 'HTML formatted text',
    'text/xml' => 'XML',
    'text/csv' => 'CSV',
    'application/json' => 'JSON',
    'text/css' => 'CSS',
    'text/javascript' => 'Javascript'
    }

  acts_as_authorization_object
  acts_as_taggable_on :tags

  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy
  has_one :metadatum, :as => :classifiable, :dependent => :destroy

  validates_inclusion_of :mime_type, :in => MIME_TYPES.keys

  accepts_nested_attributes_for :metadatum,
    :allow_destroy => true,
    :reject_if => :all_blank

  def self.select_options
    self.find(:all).collect{|c|[c.to_s,c.id]}
  end

  def self.mime_type_select_options
    MIME_TYPES.keys.collect{|f|[MIME_TYPES[f],f]}
  end

  def display_name
    name
  end

  #Export the content that's annotated in a Collage
  def content
    description
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
