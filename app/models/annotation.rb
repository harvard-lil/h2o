class Annotation < ActiveRecord::Base
  include StandardModelExtensions

  acts_as_taggable_on :layers
  belongs_to :annotated_item, :polymorphic => true
  belongs_to :user
  validates_length_of :annotation, :maximum => 10.kilobytes

  delegate :attribution, to: :user, prefix: true, allow_nil: true

  def tags
    self.layers
  end
end
