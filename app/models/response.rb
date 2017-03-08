# == Schema Information
#
# Table name: responses
#
#  id            :integer          not null, primary key
#  content       :text
#  user_id       :integer          not null
#  resource_type :string(255)      not null
#  resource_id   :integer          not null
#  created_at    :datetime
#

class Response < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true
  belongs_to :user

  default_scope { order("created_at DESC") }

  validates_presence_of :user_id, :resource_type, :resource_id

  def display_name
    "Response #{id}"
  end

  def updated_at
    created_at
  end

  def klass_partial
    'response'
  end

  def klass_sym
    klass_partial.to_sym
  end
end
