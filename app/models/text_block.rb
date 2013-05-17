class TextBlock < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods

  include H2oModelExtensions
  include StandardModelExtensions::InstanceMethods
  include AnnotatableExtensions
  include AuthUtilities
  include MetadataExtensions
  
  include ActionController::UrlWriter

  MIME_TYPES = {
    'text/plain' => 'Plain text',
    'text/html' => 'HTML formatted text'
  }
  RATINGS = {
    :collaged => 5,
    :bookmark => 1,
    :add => 3
  }

  acts_as_authorization_object
  acts_as_taggable_on :tags

  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable, :dependent => :destroy
  has_many :defects, :as => :reportable

  validates_inclusion_of :mime_type, :in => MIME_TYPES.keys
    
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
    integer :karma

    string :author
    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :metadatum, :stored => true, :multiple => true
  end

  def barcode
    Rails.cache.fetch("textblock-barcode-#{self.id}") do
      barcode_elements = self.barcode_bookmarked_added
      self.collages.each do |collage|
        barcode_elements << { :type => "collaged",
                              :date => collage.created_at, 
                              :title => "Collaged to #{collage.name}",
                              :link => collage_path(collage.id) }
      end
      barcode_elements.sort_by { |a| a[:date] }
    end
  end
end
