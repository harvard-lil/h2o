module AnnotatableExtensions
  extend ActiveSupport::Concern

  included do
    before_destroy :deleteable?
  end

  def deleteable?
    # Only allow deleting if there haven't been any collages created from this instance.
    self.collages.length == 0
  end
  def content_editable?
    # Only allow content to be edited if there haven't been any collages created from this instance.
    self.collages.length == 0
  end
end
