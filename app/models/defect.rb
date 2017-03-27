# == Schema Information
#
# Table name: defects
#
#  id              :integer          not null, primary key
#  description     :text             not null
#  reportable_id   :integer          not null
#  reportable_type :string(255)      not null
#  user_id         :integer          not null
#  created_at      :datetime
#  updated_at      :datetime
#

class Defect < ApplicationRecord  
  belongs_to :reportable, :polymorphic => true
  belongs_to :user
  validates_presence_of :reportable_id, :description, :user_id

  def name
    self.display_name
  end

  def display_name
    self.reportable.nil? ? "#{self.reportable_id}: No longer exists" : self.reportable.name
  end
end
