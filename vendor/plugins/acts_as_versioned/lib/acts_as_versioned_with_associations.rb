module ActiveRecord #:nodoc:
  module Acts
    module VersionedWithAssociations
      
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end
      
      module ClassMethods
        
        def acts_as_versioned_with_associations
        

          def self.has_many_associations
            [:has_many, :has_one, :has_and_belongs_to_many].inject([]) do |arr, macro| 
              arr + self.reflect_on_all_associations(macro)
            end           
          end
          
          def self.belongs_to_associations
            self.reflect_on_all_associations(:belongs_to)
          end
          
                    
          def self.versioned_associations(macro = :has_many)
            res = self.send("#{macro.to_s}_associations")
            res = res.reject{|association| association.name == :versions}
            res = res.reject{|association| association.options.has_key?(:through)}
            res = res.reject{|association| association.name == :tags}
            res = res.reject{|association| association.name == :tag_taggings}
            res
          end
          
          def self.has_many_versioned_associations
            self.versioned_associations
          end
          
          def self.belongs_to_versioned_associations
            self.versioned_associations(:belongs_to)
          end
          
          self.acts_as_versioned
          
          self.belongs_to_versioned_associations.each do |association|
            begin
              association.klass.class_eval do
                after_save :autosave_associated_records
              end            
            rescue NameError
            end
          end

          after_save :autosave_associated_records
          validate :ensure_copy_cannot_be_updated
        end
        
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::VersionedWithAssociations