class Migrate::Collage < ApplicationRecord
  belongs_to :annotatable, polymorphic: true
  has_many :annotations
end
