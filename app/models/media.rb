class Media < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods

  include PlaylistableExtensions
  include AuthUtilities

  acts_as_authorization_object
  
  acts_as_taggable_on :tags

  belongs_to :media_type
  validates_presence_of :name, :media_type_id, :content

  def display_name
    self.name
  end

  searchable(:include => [:tags]) do #, :annotations => {:layers => true}]) do
    text :display_name, :boost => 3.0
    string :display_name, :stored => true
    text :content, :stored => true
    string :content

    boolean :active
    boolean :public
    string :tag_list, :stored => true, :multiple => true

    string :media_type do
      media_type.slug
    end

    # add stored media type slug here
  end
end
