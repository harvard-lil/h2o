class Media < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods

  include StandardModelExtensions::InstanceMethods
  include AuthUtilities
  
  include ActionController::UrlWriter
    
  RATINGS = {
    :bookmark => 1,
    :add => 3
  }

  acts_as_authorization_object
  
  acts_as_taggable_on :tags

  belongs_to :media_type
  validates_presence_of :name, :media_type_id, :content

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
    string :author

    string :media_type do
      media_type.slug
    end

    # TODO: add stored media type slug here
  end

  def barcode
    Rails.cache.fetch("media-barcode-#{self.id}") do
      self.barcode_bookmarked_added.sort_by { |a| a[:date] }
    end
  end
end
