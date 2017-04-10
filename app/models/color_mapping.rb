# == Schema Information
#
# Table name: color_mappings
#
#  id         :integer          not null, primary key
#  collage_id :integer
#  tag_id     :integer
#  hex        :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class ColorMapping < ApplicationRecord
  belongs_to :collage
  belongs_to :tag
end
