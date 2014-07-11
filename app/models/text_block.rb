class TextBlock < ActiveRecord::Base
  include StandardModelExtensions
  include AnnotatableExtensions
  include MetadataExtensions
  include Rails.application.routes.url_helpers
  include CaptchaExtensions
  include VerifiedUserExtensions
  include DeletedItemExtensions
  include FormattingExtensions

  MIME_TYPES = {
    'text/html' => 'HTML formatted text'
  }
  RATINGS_DISPLAY = {
    :collaged => "Collaged",
    :bookmark => "Bookmarked",
    :add => "Added to"
  }

  acts_as_taggable_on :tags

  has_many :annotations, :through => :collages
  has_many :collages, :as => :annotatable
  has_many :defects, :as => :reportable
  has_many :playlist_items, :as => :actual_object, :dependent => :destroy
  belongs_to :user

  accepts_nested_attributes_for :metadatum
  validates_inclusion_of :mime_type, :in => MIME_TYPES.keys

  def self.tag_list
    Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
      JOIN tags t ON ts.tag_id = t.id
      WHERE taggable_type IN ('TextBlock', 'JournalArticle')
      GROUP BY ts.tag_id, t.name
      ORDER BY COUNT(*) DESC LIMIT 25")
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
    text :clean_description
    boolean :active
    boolean :public
    integer :karma

    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true

    string :tag_list, :stored => true, :multiple => true
    string :collages, :stored => true, :multiple => true
    string :metadatum, :stored => true, :multiple => true

    time :created_at
    time :updated_at

    string :klass, :stored => true
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end
  end

  def clean_description
    self.description.gsub!(/\p{Cc}/, "")
  end

  def barcode
    Rails.cache.fetch("textblock-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = self.barcode_bookmarked_added
      self.collages.each do |collage|
        barcode_elements << { :type => "collaged",
                              :date => collage.created_at,
                              :title => "Collaged to #{collage.name}",
                              :link => collage_path(collage),
                              :rating => 5 }
      end

      value = barcode_elements.inject(0) { |sum, item| sum + item[:rating] }
      self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end
end
