class CaseDocketNumber < ApplicationRecord
  belongs_to :case, inverse_of: :case_docket_numbers

  validates_presence_of :docket_number
  validates_length_of :docket_number, :in => 1..200

  def display_name
    self.docket_number
  end

  alias :to_s :display_name
end
