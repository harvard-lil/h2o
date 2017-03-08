# == Schema Information
#
# Table name: permissions
#
#  id              :integer          not null, primary key
#  key             :string(255)
#  label           :string(255)
#  created_at      :datetime
#  updated_at      :datetime
#  permission_type :string(255)
#

class Permission < ActiveRecord::Base
  validates_presence_of :key, :label
end
