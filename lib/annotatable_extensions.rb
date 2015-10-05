module AnnotatableExtensions
  extend ActiveSupport::Concern

  included do
    before_destroy :deleteable?
  end

  def deleteable?
    self.collages.empty?
  end

  def content_editable?
    self.collages.empty?
  end
end
