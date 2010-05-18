class Excerpt < ActiveRecord::Base
  acts_as_voteable
  acts_as_category :scope => :collage_id

  acts_as_authorization_object

  belongs_to :user
  belongs_to :collage

  validates_presence_of :anchor_x_path, :focus_x_path
  validates_length_of :reason, :in => 1..(10.kilobytes), :allow_blank => true
  validates_numericality_of :parent_id, :children_count, :ancestors_count, :descendants_count, :position, :allow_nil => true
  validates_numericality_of :anchor_sibling_offset, :anchor_offset, :focus_sibling_offset, :focus_offset, :allow_nil => true
  validates_length_of :anchor_x_path, :focus_x_path, :in => 1..(1.kilobytes)

end
