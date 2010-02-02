# == Schema Information
# Schema version: 20090828145656
#
# Table name: roles
#
#  id                :integer(4)      not null, primary key
#  name              :string(40)
#  authorizable_type :string(40)
#  authorizable_id   :integer(4)
#  created_at        :datetime
#  updated_at        :datetime
#

class Role < ActiveRecord::Base
  acts_as_authorization_role
end
