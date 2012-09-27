class TextBlock < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods

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
  has_many :defects, :as => :reportable

  validates_inclusion_of :mime_type, :in => MIME_TYPES.keys
    
  def self.autocomplete_for(context = :tags, query_term = nil)
    return [] if query_term.blank?
    self.find_by_sql(['select distinct(tags.name) from tags left join taggings on tags.id = taggings.tag_id where taggable_type = ? and context = ? and tags.name like ? order by tags.name',self.name,context.to_s,"#{query_term}%"]).collect{|t|t.name}
  end

  def self.tag_list
    Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
      JOIN tags t ON ts.tag_id = t.id
      WHERE taggable_type IN ('TextBlock', 'JournalArticle')
      GROUP BY ts.tag_id, t.name
      ORDER BY COUNT(*) DESC LIMIT 25")
  end

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
