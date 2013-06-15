class Default < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include H2oModelExtensions
  include StandardModelExtensions::InstanceMethods
  include AuthUtilities
  include Authorship

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
      barcode_elements = self.barcode_bookmarked_added.sort_by { |a| a[:date] }

      value = barcode_elements.inject(0) { |sum, item| sum += self.class::RATINGS[item[:type].to_sym].to_i; sum }
      self.update_attribute(:karma, value)

      barcode_elements
    end
  end
end
