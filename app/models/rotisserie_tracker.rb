class RotisserieTracker < ActiveRecord::Base
  acts_as_authorization_object
 
  belongs_to :rotisserie_discussion
  belongs_to :rotisserie_post
  belongs_to :user
end
