# == Schema Information
#
# Table name: case_citations
#
#  id         :integer          not null, primary key
#  case_id    :integer
#  volume     :string(200)      not null
#  reporter   :string(200)      not null
#  page       :string(200)      not null
#  created_at :datetime
#  updated_at :datetime
#

class CaseCitation < ApplicationRecord
  belongs_to :case, inverse_of: :case_citations

  validates_presence_of   :volume, :reporter, :page
  validates_length_of     :volume, :reporter, :page,  :in => 1..200

  def display_name
    "#{self.volume} #{self.reporter} #{self.page}"
  end

  alias :to_s :display_name
end
