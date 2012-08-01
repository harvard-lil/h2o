module AncestryExtensions
  module InstanceMethods
    def collapse_children
      self.children.each do|child|
        child.parent = self.parent
        child.save
      end
    end
  end
end
