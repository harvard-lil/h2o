class CaseJurisdiction < ActiveRecord::Base
  has_many :cases

  validates_presence_of :abbreviation, :name
  validates_length_of :abbreviation,  :in => 1..150
  validates_length_of :name,          :in => 1..500

  def display_name
    self.name
  end

  alias :to_s :display_name

end
