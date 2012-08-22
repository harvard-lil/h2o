class TextBlock < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include AnnotatableExtensions
  include PlaylistableExtensions
  include AuthUtilities
  include MetadataExtensions

  MIME_TYPES = {
    'text/plain' => 'Plain text',
    'text/html' => 'HTML formatted text'
  }

  acts_as_authorization_object
  acts_as_taggable_on :tags

  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy

  validates_inclusion_of :mime_type, :in => MIME_TYPES.keys

  def self.select_options
    self.find(:all).collect{|c|[c.to_s,c.id]}
  end

  def self.mime_type_select_options
    MIME_TYPES.keys.collect{|f|[MIME_TYPES[f],f]}
  end

  def display_name
    name
  end

  def bookmark_name
    self.name
  end

  #Export the content that gets annotated in a Collage - also, render the content for display.
  #As always, the content method should export valid html/XHTML.
  def content
    if mime_type == 'text/plain'
      self.class.format_content(description)
    elsif mime_type == 'text/html'
      self.class.format_html(description)
    else
      self.class.format_content(description)
    end
  end

  alias :to_s :display_name

  searchable(:include => [:metadatum, :collages, :tags]) do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    string :id, :stored => true
    text :description
    boolean :active
    boolean :public
    string :author
    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :metadatum, :stored => true, :multiple => true
  end

  def author
    owner = self.accepted_roles.find_by_name('owner')
    owner.nil? ? nil : owner.user.login.downcase
  end
end
