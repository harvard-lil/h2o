# == Schema Information
#
# Table name: case_jurisdictions
#
#  id           :integer          not null, primary key
#  abbreviation :string(150)
#  name         :string(500)
#  content      :text
#  created_at   :datetime
#  updated_at   :datetime
#

class CaseJurisdiction < ApplicationRecord
  has_many :cases
  has_many :case_requests

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
