# == Schema Information
#
# Table name: annotations
#
#  id                  :integer          not null, primary key
#  collage_id          :integer
#  annotation          :string(10240)
#  created_at          :datetime
#  updated_at          :datetime
#  pushed_from_id      :integer
#  cloned              :boolean          default(FALSE), not null
#  xpath_start         :string(255)
#  xpath_end           :string(255)
#  start_offset        :integer          default(0), not null
#  end_offset          :integer          default(0), not null
#  link                :string(255)
#  hidden              :boolean          default(FALSE), not null
#  highlight_only      :string(255)
#  annotated_item_id   :integer          default(0), not null
#  annotated_item_type :string(255)      default("Collage"), not null
#  error               :boolean          default(FALSE), not null
#  feedback            :boolean          default(FALSE), not null
#  discussion          :boolean          default(FALSE), not null
#  user_id             :integer
#

class Annotation < ApplicationRecord
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
