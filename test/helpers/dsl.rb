module H2o::Test::Helpers::DSL
  def self.included(base)
    base.class_eval do
      extend ClassMethods
      include Focusing
    end
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

  # Adds a 'focus' decorator which focuses the next test, and skips all other tests in this run
  # (Manually adding `focus:true` will not skip other tests)
  module Focusing
    def self.included(base)
      base.class_eval do
        cattr_accessor :focusing_context
        self.focusing_context = base
        cattr_accessor :focus_any
        cattr_accessor :focus_next
        def self.focus
          self.focusing_context.focus_any = true
          self.focusing_context.focus_next = true
        end
        def self.scenario(*args, &block)
          if self.focusing_context.focus_next
            metadata = if args.last.is_a? Hash
              args.last
            else
              args << (h = {}); h
            end
            metadata[:focus] = true
            self.focusing_context.focus_next = false
          end
          super
        end
        setup do
          if self.class.focus_any && !metadata[:focus]
            skip "Skipping due to focused tests"
          end
        end
      end
    end
  end
end
