class Default < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include StandardModelExtensions::InstanceMethods
  include AncestryExtensions::InstanceMethods
  include AuthUtilities
  include Authorship
  include MetadataExtensions
  include KarmaRounding
  include ActionController::UrlWriter

  RATINGS = {
    :bookmark => 1,
    :add => 3,
    :default_remix => 1
  }

  acts_as_authorization_object
  acts_as_taggable_on :tags
  has_many :playlist_items, :as => :actual_object
  belongs_to :user
  validate :url_format
  has_ancestry :orphan_strategy => :restrict

  searchable(:include => [:metadatum, :tags]) do
    text :display_name  #name
    string :display_name, :stored => true
    string :id, :stored => true
    text :url
    text :description
    integer :karma
    integer :user_id, :stored => true

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
      barcode_elements = self.barcode_bookmarked_added

      self.public_children.each do |child|
        barcode_elements << { :type => "default_remix",
                              :date => child.created_at,
                              :title => "Remixed to Link #{child.name}",
                              :link => default_path(child.id) }
      end
      
      value = barcode_elements.inject(0) { |sum, item| sum += self.class::RATINGS[item[:type].to_sym].to_i; sum }
      self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  def self.content_types_options
    %w(text audio video image other_multimedia).map { |i| [i.gsub('_', ' ').camelize, i] }
  end
end
