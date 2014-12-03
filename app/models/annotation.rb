class Annotation < ActiveRecord::Base
  include StandardModelExtensions

  acts_as_taggable_on :layers
  belongs_to :collage
  belongs_to :user
  delegate :user, to: :collage
  validates_length_of :annotation, :maximum => 10.kilobytes

  def display_name
    "On \"#{self.collage.name}\",  #{self.created_at.to_s(:simpledatetime)} by " + self.user.login
  end

  alias :name :display_name
  alias :to_s :display_name

  def tags
    self.layers
  end
end
