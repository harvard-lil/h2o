class RawContent < ApplicationRecord
  belongs_to :source, polymorphic: true
end
