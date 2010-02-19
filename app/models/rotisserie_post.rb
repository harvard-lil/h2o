class RotisseriePost < ActiveRecord::Base
  belongs_to :rotisserie_discussion
  has_many :rotisserie_assignments
  has_many :rotisserie_trackers

end
