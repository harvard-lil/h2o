class Annotation < ActiveRecord::Base
  include StandardModelExtensions

  acts_as_taggable_on :layers
  belongs_to :annotated_item, :polymorphic => true
  belongs_to :user
  validates_length_of :annotation, :maximum => 10.kilobytes

  html_fragment :annotation, :scrub => :strip

  before_validation do |record|
    # Homegrown version of the Loofah call for annotation above
    if record.link.to_s.match(/javascript:|onClick|'|"/)
      record.errors.add(:link, "Invalid characters")
    end
  end

  delegate :attribution, to: :user, prefix: true, allow_nil: true

  def tags
    self.layers
  end
end
