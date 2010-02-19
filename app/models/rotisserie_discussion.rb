class RotisserieDiscussion < ActiveRecord::Base
  belongs_to :rotisserie_instance
  has_many :rotisserie_posts
  has_many :rotisserie_assignments
  has_many :rotisserie_trackers
end
