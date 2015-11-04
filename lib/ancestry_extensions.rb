module AncestryExtensions
  extend ActiveSupport::Concern

  included do
    before_validation :clean_ancestry
  end

  def collapse_children
    self.children.each do|child|
      child.parent = self.parent
      child.save
    end
  end
  def public_children
    self.children.select { |c| c.public }
  end

  private

  def clean_ancestry
    self.ancestry = nil unless ancestry.present?
  end
end
