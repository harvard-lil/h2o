# == Schema Information
#
# Table name: case_docket_numbers
#
#  id            :integer          not null, primary key
#  case_id       :integer
#  docket_number :string(200)      not null
#  created_at    :datetime
#  updated_at    :datetime
#

class CaseDocketNumber < ActiveRecord::Base
  belongs_to :case

  validates_presence_of :docket_number
  validates_length_of :docket_number, :in => 1..200

  def display_name
    self.docket_number
  end

  alias :to_s :display_name
end
