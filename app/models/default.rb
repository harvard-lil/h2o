class Default < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include StandardModelExtensions::InstanceMethods
  include AuthUtilities

  include ActionController::UrlWriter

  RATINGS = {
    :bookmark => 1,
    :add => 3
  }

  acts_as_authorization_object
  acts_as_taggable_on :tags

  searchable do
    text :display_name  #name
    string :display_name, :stored => true
    string :id, :stored => true
    text :url
    text :description
    integer :karma
    string :author 

    boolean :public
    boolean :active

    time :created_at
  end

  def display_name
    self.name
  end

  def barcode
    Rails.cache.fetch("itemdefault-barcode-#{self.id}") do
      self.barcode_bookmarked_added.sort_by { |a| a[:date] }
    end
  end
end
