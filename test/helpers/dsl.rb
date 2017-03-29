module H2o::Test::Helpers::DSL
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def scenario(*args, &block)
      self.it *args, &block
    end
    def top_level_feature_blocks
      ActiveSupport::Deprecation.warn "Top-level feature blocks are deprecated. Remove this code."
      top_level_feature_superclass = self
      Object.send(:define_method, :feature) do |name, &block|
        ActiveSupport::Deprecation.warn "Top-level feature blocks are deprecated. Change this to `class #{name.classify}SystemTest < #{top_level_feature_superclass.name}`"
        feature_class = Class.new top_level_feature_superclass, &block
      end
    end
  end
end
