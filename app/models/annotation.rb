require 'tagging_extensions'

class Annotation < ActiveRecord::Base
  extend TaggingExtensions::ClassMethods
  include TaggingExtensions::InstanceMethods

  acts_as_voteable
  acts_as_category :scope => :collage_id
  acts_as_taggable_on :layers

  acts_as_authorization_object

  belongs_to :user
  belongs_to :collage

  validates_presence_of :annotation_start, :annotation_end
  validates_length_of :annotation, :maximum => 10.kilobytes
  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true

end
