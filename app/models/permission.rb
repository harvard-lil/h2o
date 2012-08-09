class Permission < ActiveRecord::Base
  validates_presence_of :key, :label
end
