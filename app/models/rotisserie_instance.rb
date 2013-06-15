class RotisserieInstance < ActiveRecord::Base
  include AuthUtilities
  include Authorship
  acts_as_authorization_object

  has_many :rotisserie_discussions, :order => :id
  has_many :roles, :as => :authorizable

  validates_presence_of :title
  validates_uniqueness_of :title

  def output_text
    self.output
  end

end
