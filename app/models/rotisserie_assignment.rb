class RotisserieAssignment < ActiveRecord::Base
  belongs_to :rotisserie_discussion
  belongs_to :rotisserie_post
  belongs_to :user
end
