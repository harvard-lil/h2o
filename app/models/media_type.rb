class MediaType < ActiveRecord::Base
  def to_s
    "#{self.label}"
  end
end
