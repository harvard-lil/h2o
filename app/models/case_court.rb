class CaseCourt < ApplicationRecord
  has_many :cases, inverse_of: :case_court

  validates_presence_of :abbreviation, :name
  validates_length_of :abbreviation,  :in => 1..150
  validates_length_of :name,          :in => 1..500

  def display_name
    self.name
  end

  def user
    User.where(login: 'h2ocases').first
  end

  alias :to_s :display_name
end
