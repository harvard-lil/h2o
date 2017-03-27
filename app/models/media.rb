# == Schema Information
#
# Table name: medias
#
#  id                 :integer          not null, primary key
#  name               :string(255)
#  content            :text
#  media_type_id      :integer
#  public             :boolean          default(TRUE)
#  created_at         :datetime
#  updated_at         :datetime
#  description        :string(5242880)
#  karma              :integer
#  pushed_from_id     :integer
#  user_id            :integer          default(0), not null
#  created_via_import :boolean          default(FALSE), not null
#

class Media < ApplicationRecord
  self.table_name = "medias"

  include StandardModelExtensions
  include CaptchaExtensions
  include VerifiedUserExtensions
  include SpamPreventionExtension
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
  before_save :filter_harvard_urls
  validate :is_secure

  def is_secure
    http_match = self.content.scan(/http:\/\//)
    if http_match.size > 0
      self.errors.add(:content, "must be secure (link to https).")
    end
  end

  def filter_harvard_urls
    if self.content.match(/wiki.harvard.edu/)
      self.content.gsub!(/\?[^"]*/, '')
    end
  end

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

  def h2o_clone(new_user, params)
    media_copy = self.dup
    media_copy.karma = 0
    media_copy.user = new_user
    media_copy.name = params[:name] if params.has_key?(:name)
    media_copy.description = params[:description] if params.has_key?(:description)
    media_copy 
  end
end
