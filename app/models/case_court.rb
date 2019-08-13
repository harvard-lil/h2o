class CaseCourt < ApplicationRecord
  include Capapi::ModelHelpers
  CAPAPI_CLASS = Capapi::Court

  has_many :cases, inverse_of: :case_court

  validates_presence_of :name_abbreviation, :name
  validates_length_of   :name_abbreviation, :in => 1..150
  validates_length_of   :name,              :in => 1..500

  def display_name
    self.name
  end

  alias :to_s :display_name
end
