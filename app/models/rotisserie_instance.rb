class RotisserieInstance < ActiveRecord::Base
  has_many :rotisserie_discussions

  validates_presence_of :title
  validates_uniqueness_of :title
end
