class CaseDocketNumber < ActiveRecord::Base
  belongs_to :case

  validates_presence_of :docket_number
  validates_length_of :docket_number, :in => 1..200

  def display_name
    self.docket_number
  end

  alias :to_s :display_name

end
