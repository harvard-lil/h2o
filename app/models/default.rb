class Default < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include StandardModelExtensions::InstanceMethods
  include AuthUtilities
  include Authorship
  include MetadataExtensions
  include KarmaRounding
  include ActionController::UrlWriter

  RATINGS = {
    :bookmark => 1,
    :add => 3
  }

  acts_as_authorization_object
  acts_as_taggable_on :tags
  has_many :playlist_items, :as => :actual_object
  belongs_to :user
  validate :url_format

  searchable(:include => [:metadatum, :tags]) do
    text :display_name  #name
    string :display_name, :stored => true
    string :id, :stored => true
    text :url
    text :description
    integer :karma

    string :tag_list, :stored => true, :multiple => true
    string :metadatum, :stored => true, :multiple => true

    string :user
    boolean :public
    boolean :active

    time :created_at
    time :updated_at
  end

  def url_format
    self.errors.add(:url, "URL must be an absolute path (it must contain http)") if !self.url.match(/^http/)
  end

  def display_name
    self.name
  end

  def barcode
    Rails.cache.fetch("default-barcode-#{self.id}") do
      barcode_elements = self.barcode_bookmarked_added.sort_by { |a| a[:date] }

      value = barcode_elements.inject(0) { |sum, item| sum += self.class::RATINGS[item[:type].to_sym].to_i; sum }
      self.update_attribute(:karma, value)

      barcode_elements
    end
  end

  def self.content_types_options
    %w(text audio video image other_multimedia).map { |i| [i.gsub('_', ' ').camelize, i] }
  end
end
