# == Schema Information
#
# Table name: institutions
#
#  id         :integer          not null, primary key
#  name       :string(255)      not null
#  created_at :datetime
#  updated_at :datetime
#

class Institution < ActiveRecord::Base
  validates_presence_of :name
  has_and_belongs_to_many :users
end
