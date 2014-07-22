class Media < ActiveRecord::Base
  self.table_name = "medias"

  include StandardModelExtensions
  include CaptchaExtensions
  include VerifiedUserExtensions
  include SpamPreventionExtension
  include FormattingExtensions
  include DeletedItemExtensions
  include Rails.application.routes.url_helpers

  RATINGS_DISPLAY = {
    :bookmark => "Bookmarked",
    :add => "Added to"
  }

  acts_as_taggable_on :tags

  belongs_to :media_type
  belongs_to :user
  validates_presence_of :name, :media_type_id, :content
  has_many :playlist_items, :as => :actual_object

  def is_pdf?
    self.media_type.slug == 'pdf'
  end

  def typed_content
    self.is_pdf? ? self.pdf_content : self.content
  end

  def pdf_content
    self.has_html? ? self.content : "<iframe src='#{self.content.strip}' width='100%' height='100%'></iframe>"
  end

  def has_html?
    self.content =~ /<\/?\w+((\s+\w+(\s*=\s*(?:".*?"|'.*?'|[^'">\s]+))?)+\s*|\s*)\/?>/imx
  end

  def display_name
    self.name
  end

  searchable(:include => [:tags]) do #, :annotations => {:layers => true}]) do
    string :id, :stored => true
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    text :content, :stored => true
    string :content
    integer :karma

    boolean :active
    boolean :public
    string :tag_list, :stored => true, :multiple => true

    time :created_at
    time :updated_at
    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true

    string :media_type do
      media_type.slug
    end
    
    string :klass, :stored => true
    boolean :primary do
      false
    end
    boolean :secondary do
      false
    end
  end

  def barcode
    Rails.cache.fetch("media-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = self.barcode_bookmarked_added.sort_by { |a| a[:date] }

      value = barcode_elements.inject(0) { |sum, item| sum + item[:rating] }
      self.update_attribute(:karma, value)

      barcode_elements
    end
  end
end
