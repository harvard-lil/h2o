# == Schema Information
#
# Table name: media_types
#
#  id         :integer          not null, primary key
#  label      :string(255)
#  slug       :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class MediaType < ApplicationRecord
  def to_s
    "#{self.label}"
  end
end
