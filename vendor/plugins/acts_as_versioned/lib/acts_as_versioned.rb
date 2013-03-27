# Copyright (c) 2005 Rick Olson
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module ActiveRecord #:nodoc:
  module Acts #:nodoc:
    # Specify this act if you want to save a copy of the row in a versioned table.  This assumes there is a 
    # versioned table ready and that your model has a version field.  This works with optimistic locking if the lock_version
    # column is present as well.
    #
    # The class for the versioned model is derived the first time it is seen. Therefore, if you change your database schema you have to restart
    # your container for the changes to be reflected. In development mode this usually means restarting WEBrick.
    #
    #   class Page < ActiveRecord::Base
    #     # assumes pages_versions table
    #     acts_as_versioned
    #   end
    #
    # Example:
    #
    #   page = Page.create(:title => 'hello world!')
    #   page.version       # => 1
    #
    #   page.title = 'hello world'
    #   page.save
    #   page.version       # => 2
    #   page.versions.size # => 2
    #
    #   page.revert_to(1)  # using version number
    #   page.title         # => 'hello world!'
    #
    #   page.revert_to(page.versions.last) # using versioned instance
    #   page.title         # => 'hello world'
    #
    #   page.versions.earliest # efficient query to find the first version
    #   page.versions.latest   # efficient query to find the most recently created version
    #
    #
    # Simple Queries to page between versions
    #
    #   page.versions.before(version) 
    #   page.versions.after(version)
    #
    # Access the previous/next versions from the versioned model itself
    #
    #   version = page.versions.latest
    #   version.previous # go back one version
    #   version.next     # go forward one version
    #
    # See ActiveRecord::Acts::Versioned::ClassMethods#acts_as_versioned for configuration options
    module Versioned
      CALLBACKS = [:set_new_version, :save_version, :save_version?]
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end
      
    
      
      module ClassMethods        
        
        # == Configuration options
        #
        # * <tt>class_name</tt> - versioned model class name (default: PageVersion in the above example)
        # * <tt>table_name</tt> - versioned model table name (default: page_versions in the above example)
        # * <tt>foreign_key</tt> - foreign key used to relate the versioned model to the original model (default: page_id in the above example)
        # * <tt>inheritance_column</tt> - name of the column to save the model's inheritance_column value for STI.  (default: versioned_type)
        # * <tt>version_column</tt> - name of the column in the model that keeps the version number (default: version)
        # * <tt>sequence_name</tt> - name of the custom sequence to be used by the versioned model.
        # * <tt>limit</tt> - number of revisions to keep, defaults to unlimited
        # * <tt>if</tt> - symbol of method to check before saving a new version.  If this method returns false, a new version is not saved.
        #   For finer control, pass either a Proc or modify Model#version_condition_met?
        #
        #     acts_as_versioned :if => Proc.new { |auction| !auction.expired? }
        #
        #   or...
        #
        #     class Auction
        #       def version_condition_met? # totally bypasses the <tt>:if</tt> option
        #         !expired?
        #       end
        #     end
        #
        # * <tt>if_changed</tt> - Simple way of specifying attributes that are required to be changed before saving a model.  This takes
        #   either a symbol or array of symbols.
        #
        # * <tt>extend</tt> - Lets you specify a module to be mixed in both the original and versioned models.  You can also just pass a block
        #   to create an anonymous mixin:
        #
        #     class Auction
        #       acts_as_versioned do
        #         def started?
        #           !started_at.nil?
        #         end
        #       end
        #     end
        #
        #   or...
        #
        #     module AuctionExtension
        #       def started?
        #         !started_at.nil?
        #       end
        #     end
        #     class Auction
        #       acts_as_versioned :extend => AuctionExtension
        #     end
        #
        #  Example code:
        #
        #    @auction = Auction.find(1)
        #    @auction.started?
        #    @auction.versions.first.started?
        #
        # == Database Schema
        #
        # The model that you're versioning needs to have a 'version' attribute. The model is versioned 
        # into a table called #{model}_versions where the model name is singlular. The _versions table should 
        # contain all the fields you want versioned, the same version column, and a #{model}_id foreign key field.
        #
        # A lock_version field is also accepted if your model uses Optimistic Locking.  If your table uses Single Table inheritance,
        # then that field is reflected in the versioned model as 'versioned_type' by default.
        #
        # Acts_as_versioned comes prepared with the ActiveRecord::Acts::Versioned::ActMethods::ClassMethods#create_versioned_table 
        # method, perfect for a migration.  It will also create the version column if the main model does not already have it.
        #
        #   class AddVersions < ActiveRecord::Migration
        #     def self.up
        #       # create_versioned_table takes the same options hash
        #       # that create_table does
        #       Post.create_versioned_table
        #     end
        # 
        #     def self.down
        #       Post.drop_versioned_table
        #     end
        #   end
        # 
        # == Changing What Fields Are Versioned
        #
        # By default, acts_as_versioned will version all but these fields: 
        # 
        #   [self.primary_key, inheritance_column, 'version', 'lock_version', versioned_inheritance_column]
        #
        # You can add or change those by modifying #non_versioned_columns.  Note that this takes strings and not symbols.
        #
        #   class Post < ActiveRecord::Base
        #     acts_as_versioned
        #     self.non_versioned_columns << 'comments_count'
        #   end
        # 
        REJECTED_ASSOCIATIONS = [:versions, :tag, :taggables, :taggings, :tagging, :taggable, :tags,
                                 :tag_taggings, :base_tags, :playlist, :playlists, :playlist_item, :playlist_items]
        def acts_as_versioned(options = {}, &extension)
          
  
          
          # don't allow multiple calls
          return if self.included_modules.include?(ActiveRecord::Acts::Versioned::ActMethods)
          
          
          def self.white_listed_associations(macro = nil)
            res = self.reflect_on_all_associations(macro)
            res = res.reject{|association| association.options.has_key?(:through)}
            REJECTED_ASSOCIATIONS.each do |reject|
              res = res.reject{|association| association.name == reject}
            end
            res = res.reject{|association| association.options[:readonly]}            
            res
          end
          
          def self.has_many_associations
            [:has_many, :has_one].inject([]) do |arr, macro| 
              arr + self.white_listed_associations(macro)
            end           
          end
          
          def self.has_and_belongs_to_many_associations
            [:has_and_belongs_to_many].inject([]) do |arr, macro| 
              arr + self.white_listed_associations(macro)
            end           
            
          end
          
          def self.belongs_to_associations
            self.white_listed_associations(:belongs_to)
          end


          def self.versioned_associations(macro = :has_many)
            self.send("#{macro.to_s}_associations")
          end

          def self.has_and_belongs_to_many_versioned_associations
            self.versioned_associations(:has_and_belongs_to_many)
          end
          
          def self.has_many_versioned_associations
            self.versioned_associations
          end

          def self.belongs_to_versioned_associations
            self.versioned_associations(:belongs_to)
          end          
          
          send :include, ActiveRecord::Acts::Versioned::ActMethods


          cattr_accessor :versioned_class_name, :versioned_foreign_key, :versioned_table_name, :versioned_inheritance_column, 
            :version_column, :max_version_limit, :track_altered_attributes, :version_condition, :version_sequence_name, :non_versioned_columns,
            :version_association_options, :version_if_changed

          self.versioned_class_name         = options[:class_name]  || "Version"
          self.versioned_foreign_key        = options[:foreign_key] || self.to_s.foreign_key
          self.versioned_table_name         = options[:table_name]  || "#{table_name_prefix}#{base_class.name.demodulize.underscore}_versions#{table_name_suffix}"
          self.versioned_inheritance_column = options[:inheritance_column] || "versioned_#{inheritance_column}"
          self.version_column               = options[:version_column]     || 'version'
          self.version_sequence_name        = options[:sequence_name]
          self.max_version_limit            = options[:limit].to_i
          self.version_condition            = options[:if] || true
          self.non_versioned_columns        = [self.primary_key, inheritance_column, self.version_column, 'lock_version', versioned_inheritance_column] + options[:non_versioned_columns].to_a.map(&:to_s)
          self.version_association_options  = {
                                                :class_name  => "#{self.to_s}::#{versioned_class_name}",
                                                :foreign_key => versioned_foreign_key,
                                                :dependent   => :delete_all
                                              }.merge(options[:association_options] || {})

          if block_given?
            extension_module_name = "#{versioned_class_name}Extension"
            silence_warnings do
              self.const_set(extension_module_name, Module.new(&extension))
            end

            options[:extend] = self.const_get(extension_module_name)
          end
          
          
          
          class_eval <<-CLASS_METHODS
            attr_accessor :copy
            has_many :versions, version_association_options do
              # finds earliest version of this record
              def earliest
                @earliest ||= find(:first, :order => '#{version_column}')
              end

              # find latest version of this record
              def latest
                @latest ||= find(:first, :order => '#{version_column} desc')
              end
            end
            before_save  :set_new_version
            after_save   :save_version
            after_save   :clear_old_versions

            unless options[:if_changed].nil?
              self.track_altered_attributes = true
              options[:if_changed] = [options[:if_changed]] unless options[:if_changed].is_a?(Array)
              self.version_if_changed = options[:if_changed].map(&:to_s)
            end

            include options[:extend] if options[:extend].is_a?(Module)

          CLASS_METHODS
          
          # create the dynamic versioned model
          const_set(versioned_class_name, Class.new(ActiveRecord::Base)).class_eval do
            def self.reloadable? ; false ; end
            # find first version before the given version
            def self.before(version)
              find :first, :order => 'version desc',
                :conditions => ["#{original_class.versioned_foreign_key} = ? and version < ?", version.send(original_class.versioned_foreign_key), version.version]
            end

            # find first version after the given version.
            def self.after(version)
              find :first, :order => 'version',
                :conditions => ["#{original_class.versioned_foreign_key} = ? and version > ?", version.send(original_class.versioned_foreign_key), version.version]
            end

            def previous
              self.class.before(self)
            end

            def next
              self.class.after(self)
            end

            def versions_count
              page.version
            end
          end

          versioned_class.cattr_accessor :original_class
          versioned_class.original_class = self
          versioned_class.set_table_name versioned_table_name
          versioned_class.send :include, options[:extend]         if options[:extend].is_a?(Module)
          versioned_class.set_sequence_name version_sequence_name if version_sequence_name
          
          
        
          self.reflect_on_all_associations.each do |association|
            alias_method("orig_#{association.name.to_s}".to_sym, association.name) 
          end
          
          def self.shallow_copy(version_model, new_model = self.new)
            self.columns.each do |col|
              new_model.send("#{col.name}=", version_model.send(col.name)) if version_model.has_attribute?(col.name)
            end
            new_model.id = version_model.send("#{self.to_s.underscore}_id")
            new_model[new_model.class.inheritance_column] = version_model[self.versioned_inheritance_column]
            new_model.copy = true
            new_model.instance_variable_set('@new_record', false)
            new_model
          end
          
          def self.copy_by_id_and_version(id, version)
            obj = self.find(id)
            version = obj.versions.find_by_version(version)
            new_copy = self.shallow_copy(version)
            new_copy
          end
          
          self.belongs_to_versioned_associations.each do |association|          
            define_method(association.name) do
              
              if self.copy?
                if association.polymorphic?
                  return nil if self.original.annotatable.nil?
                  association_klass = self.send("#{association.polymorphic_name}_type").constantize
                  belongs_to_versioned_class = association_klass.versioned_class
                  belongs_to_foreign_key = association_klass.versioned_foreign_key
                  local_foreign_key = "#{association.polymorphic_name}_id"
                  local_version = "#{association.polymorphic_name}_version"
                else
                  association_klass = association.klass
                  belongs_to_versioned_class = association_klass.versioned_class
                  belongs_to_foreign_key = association_klass.versioned_foreign_key
                  local_foreign_key = association_klass.versioned_foreign_key
                  local_version = "#{association_klass.to_s.underscore}_version"
                end
                 found_version = belongs_to_versioned_class.find :first, :conditions => ["#{belongs_to_foreign_key} = ? 
                                                                               AND version = ?", self.send(local_foreign_key),
                                                                                                 self.send(local_version)]                                                          
                 if found_version
                   association_klass.shallow_copy(found_version)                                                                           
                 else
                  nil
                 end
              else
                self.send("orig_#{association.name.to_s}")
              end            
              
            end
            
          end
          
          self.has_and_belongs_to_many_versioned_associations.each do |association|          
            if association.polymorphic?          
              parent_foreign_key = "#{association.options[:as]}_id"
              parent_version = "#{association.options[:as]}_version"
            elsif association.options.has_key?(:foreign_key)
              parent_foreign_key = association.options[:foreign_key]
              parent_version = association.options[:foreign_key].gsub("_id", "_version")
            else
              parent_foreign_key = "#{self.to_s.underscore}_id"
              parent_version = "#{self.to_s.underscore}_version"
            end
            
            define_method(association.name) do
                if self.copy? 
                  sql = "SELECT tb1.*
                         FROM #{association.klass.versioned_table_name} tb1
                         INNER JOIN #{association.options[:join_table]}_versions tb2
                         ON tb1.#{association.association_foreign_key} = tb2.#{association.association_foreign_key}
                         AND tb1.version = tb2.#{association.association_foreign_key.gsub("_id", '')}_version
                         WHERE tb2.#{association.primary_key_name} = #{self.id}
                         AND tb2.#{association.primary_key_name.gsub("_id", '')}_version = #{self.version}"
                         
                         
                  found_versions = association.klass.version_association_options[:class_name].constantize.find_by_sql(sql)

                  if found_versions.any?
                    found_versions.inject([]){|arr, found_version| arr << association.klass.shallow_copy(found_version)}
                  else
                    []
                  end
                else
                  self.send("orig_#{association.name.to_s}")
                end
            end
            
            
            class_methods =  <<-CLASS_METHODS
            
            after_save :update_#{association.options[:join_table]}_versions              

            CLASS_METHODS
            self.class_eval(class_methods)
            
            define_method("update_#{association.options[:join_table]}_versions") do
              self.send(association.name).each do |obj|              
                sql = "SELECT * FROM #{association.options[:join_table]}_versions 
                       WHERE #{association.primary_key_name} = #{self.id}
                       AND   #{association.association_foreign_key} = #{obj.id}
                       AND   #{association.primary_key_name.gsub("_id", '')}_version = #{self.version}
                       AND   #{association.association_foreign_key.gsub("_id", '')}_version = #{obj.version};"
                       
                result = self.connection.execute(sql)
                row_count = result.respond_to?(:num_rows) ? result.num_rows : result.num_tuples
                if row_count == 0 
                  sql = "INSERT INTO #{association.options[:join_table]}_versions 
                         (#{association.primary_key_name}, #{association.association_foreign_key}, #{association.primary_key_name.gsub("_id", '')}_version, #{association.association_foreign_key.gsub("_id", '')}_version) 
                         VALUES 
                         ( #{self.id},#{obj.id}, #{self.version}, #{obj.version});"
                  self.connection.execute(sql)
                end
              end
            end
            insert_sql = "INSERT INTO #{association.options[:join_table]}"
            insert_sql += " (#{association.primary_key_name}, #{association.association_foreign_key}, #{association.primary_key_name.gsub("_id", '')}_version, #{association.association_foreign_key.gsub("_id", '')}_version) "
            insert_sql += ' VALUES ( #{self.id}, #{record.id}, #{self.version}, #{record.version})'
            association.options[:insert_sql] = insert_sql
          end
          
          self.has_many_versioned_associations.each do |association|
            if association.polymorphic?          
              parent_foreign_key = "#{association.options[:as]}_id"
              parent_version = "#{association.options[:as]}_version"
            elsif association.options.has_key?(:foreign_key)
              parent_foreign_key = association.options[:foreign_key]
              parent_version = association.options[:foreign_key].gsub("_id", "_version")
            else
              parent_foreign_key = "#{self.to_s.underscore}_id"
              parent_version = "#{self.to_s.underscore}_version"
            end
            
            define_method(association.name) do
                if self.copy? 
                  sql = "SELECT tb1.*
                         FROM #{association.klass.versioned_table_name} tb1
                         INNER JOIN
                             (
                             SELECT #{association.klass.versioned_foreign_key}, MAX(version) AS MaxVersion
                             FROM #{association.klass.versioned_table_name}
                             WHERE #{association.klass.versioned_table_name}.#{parent_foreign_key} = #{self.id} AND #{association.klass.versioned_table_name}.#{parent_version} = #{self.version}
                             GROUP BY #{association.klass.versioned_foreign_key}, #{parent_foreign_key}, #{parent_version}
                             ) groupedtbl ON tb1.#{association.klass.versioned_foreign_key} = groupedtbl.#{association.klass.versioned_foreign_key} AND tb1.version = groupedtbl.MaxVersion;"
                  found_versions = association.klass.versioned_class.find_by_sql(sql)
                  #puts sql
                  if found_versions.any?
                    found_versions.inject([]){|arr, found_version| arr << association.klass.shallow_copy(found_version)}
                  else
                    []
                  end
                else
                  self.send("orig_#{association.name.to_s}")
                end

            end
                      
            define_method(:versions) do
              if self.copy?
                self.original.versions
              else
                self.send("orig_versions")
              end
            end
            
            if association.polymorphic? 
              parent_klass = association.polymorphic_name.to_s
            elsif association.options[:foreign_key]
              parent_klass = association.options[:foreign_key].gsub("_id", '')
            else
              parent_klass = self.to_s.underscore
            end                  
              

            class_methods =  <<-CLASS_METHODS
            
            before_validation :update_#{parent_klass}_version_number
            def update_#{parent_klass}_version_number
              if self.#{parent_klass}
                  self.#{parent_klass}.reload 
                  if self.#{parent_klass}.respond_to?(:version)
                    self.#{parent_klass}_version = self.#{parent_klass}.version
                  end
              end
            end

            CLASS_METHODS
            association.klass.class_eval(class_methods)

            association.options[:before_add] = "set_#{parent_klass}_version".to_sym
            self.write_inheritable_attribute("before_add_for_#{association.name}".to_sym, ["set_#{parent_klass}_version".to_sym])

            self.class_eval do
              define_method("set_#{parent_klass}_version") do |target|
                target.send("#{parent_klass}_version=", self.version)
              end
            end
            
          end #end_has_many_block
          
          send :include, ActiveRecord::Acts::Versioned::ActsWithAssociationMethods

          self.white_listed_associations.each do |association| 
            
            begin
              klass = association.klass
              unless klass.respond_to?(:create_versioned_table)
                association.klass.acts_as_versioned
              end
            rescue NameError
            end
          end          
          
        end
      end
      
      
      
      module ActsWithAssociationMethods
        def self.included(base) # :nodoc:
          base.extend ClassMethods          
        end
        
        def autosave_associated_records  
          associations = self.class.has_many_versioned_associations
          associations.map(&:name).each do |name|
            associated_records = self.send(name) || []
            associated_records.each do |associated_record| 
              associated_record.reload
              associated_record.save!
            end
          end
        end
        
        
       
      end
      
      module ActMethods
        def self.included(base) # :nodoc:
          base.extend ClassMethods          
        end
        

        # Saves a version of the model in the versioned table.  This is called in the after_save callback by default
        def save_version
          if @saving_version
            @saving_version = nil
            rev = self.class.versioned_class.new
            clone_versioned_model(self, rev)
            rev.send("#{self.class.version_column}=", send(self.class.version_column))
            rev.send("#{self.class.versioned_foreign_key}=", id)
            rev.save
          end
        end

        # Clears old revisions if a limit is set with the :limit option in <tt>acts_as_versioned</tt>.
        # Override this method to set your own criteria for clearing old versions.
        def clear_old_versions
          return if self.class.max_version_limit == 0
          excess_baggage = send(self.class.version_column).to_i - self.class.max_version_limit
          if excess_baggage > 0
            self.class.versioned_class.delete_all ["#{self.class.version_column} <= ? and #{self.class.versioned_foreign_key} = ?", excess_baggage, id]
          end
        end

        # Reverts a model to a given version.  Takes either a version number or an instance of the versioned model
        def revert_to(version)
          if version.is_a?(self.class.versioned_class)
            return false unless version.send(self.class.versioned_foreign_key) == id and !version.new_record?
          else
            return false unless version = versions.send("find_by_#{self.class.version_column}", version)
          end
          self.clone_versioned_model(version, self)
          send("#{self.class.version_column}=", version.send(self.class.version_column))
          true
        end

        # Reverts a model to a given version and saves the model.
        # Takes either a version number or an instance of the versioned model
        def revert_to!(version)
          revert_to(version) ? save_without_revision : false
        end
        

        # Temporarily turns off Optimistic Locking while saving.  Used when reverting so that a new version is not created.
        def save_without_revision
          save_without_revision!
          true
        rescue
          false
        end

        def save_without_revision!
          without_locking do
            without_revision do
              save!
            end
          end
        end
        
        def altered?
          track_altered_attributes ? (version_if_changed - changed).length < version_if_changed.length : changed?
        end
        
        # Clones a model.  Used when saving a new version or reverting a model's version.
        def clone_versioned_model(orig_model, new_model)
          self.class.versioned_columns.each do |col|
            new_model.send("#{col.name}=", orig_model.send(col.name)) if orig_model.has_attribute?(col.name)
          end

          if orig_model.is_a?(self.class.versioned_class)
            new_model[new_model.class.inheritance_column] = orig_model[self.class.versioned_inheritance_column]
          elsif new_model.is_a?(self.class.versioned_class)
            new_model[self.class.versioned_inheritance_column] = orig_model[orig_model.class.inheritance_column]
          end
        end

        # Checks whether a new version shall be saved or not.  Calls <tt>version_condition_met?</tt> and <tt>changed?</tt>.
        def save_version?
          version_condition_met? && altered?
        end
        
        # Checks condition set in the :if option to check whether a revision should be created or not.  Override this for
        # custom version condition checking.
        def version_condition_met?
          case
          when version_condition.is_a?(Symbol)
            send(version_condition)
          when version_condition.respond_to?(:call) && (version_condition.arity == 1 || version_condition.arity == -1)
            version_condition.call(self)
          else
            version_condition
          end
        end

        # Executes the block with the versioning callbacks disabled.
        #
        #   @foo.without_revision do
        #     @foo.save
        #   end
        #
        def without_revision(&block)
          self.class.without_revision(&block)
        end

        # Turns off optimistic locking for the duration of the block
        #
        #   @foo.without_locking do
        #     @foo.save
        #   end
        #
        def without_locking(&block)
          self.class.without_locking(&block)
        end

        def empty_callback() end #:nodoc:
        
        def copy?
          self.copy
        end
        
        def original
          if self.copy?
            self.class.find(self.id)
          end
        end   
        
        def ensure_copy_cannot_be_updated 
          raise "versions are not editable" if self.copy?
        end
        
        protected
          # sets the new version before saving, unless you're using optimistic locking.  In that case, let it take care of the version.
          def set_new_version
            @saving_version = new_record? || save_version?
            self.send("#{self.class.version_column}=", next_version) if new_record? || (!locking_enabled? && save_version?)
          end

          # Gets the next available version for the current record, or 1 for a new record
          def next_version
            (new_record? ? 0 : versions.calculate(:max, version_column).to_i) + 1
          end

        module ClassMethods
          # Returns an array of columns that are versioned.  See non_versioned_columns
          def versioned_columns
            @versioned_columns ||= columns.select { |c| !non_versioned_columns.include?(c.name) }
          end

          # Returns an instance of the dynamic versioned model
          def versioned_class
            const_get versioned_class_name
          end
          
          def columns_that_hold_version_info(tbl_name = self.table_name)
            ActiveRecord::Base.connection.columns(tbl_name).find_all{|c| c.name =~/version/}
          end

          def seed_insert_sql
            insert_sql = "DELETE FROM #{self.versioned_table_name}; "
            insert_sql += "INSERT INTO #{self.versioned_table_name} " 
            insert_sql += "(#{self.columns.reject{|c| c.name=="id"}.map(&:name).join(", ")}, #{self.versioned_foreign_key}) "
            insert_sql += "SELECT #{self.columns.reject{|c| c.name=="id"}.map(&:name).join(", ")},  id "
            insert_sql += "FROM #{self.table_name};"              
            insert_sql
          end

          def seed_update_sql
            update_sql = "UPDATE #{self.table_name} "
            update_sql += "SET #{self.columns_that_hold_version_info.map{|c| "#{c.name}=1"}.join(", ")}"
            update_sql += ";"
            update_sql
          end

          def seed_habtm_join_tables
            self.has_and_belongs_to_many_versioned_associations.each do |association|
               jt = association.options[:join_table]
               jt_columns = ActiveRecord::Base.connection.columns(jt).map(&:name).join(", ")
               jtv =  "#{jt}_versions"
               sql =  "UPDATE #{jt} "
               sql += "SET #{self.columns_that_hold_version_info(jt).map{|c| "#{c.name}=1"}.join(", ")}; "
               sql += "DELETE FROM #{jtv}; "
               sql += "INSERT INTO #{jtv} (#{jt_columns}) "
               sql += "SELECT #{jt_columns} FROM #{jt}; "
               ActiveRecord::Base.connection.execute(sql)
            end           
          end

          def seed_versioned_data
            ActiveRecord::Base.connection.execute(self.seed_update_sql)
            ActiveRecord::Base.connection.execute(self.seed_insert_sql)
            self.seed_habtm_join_tables
          end
          
          # Rake migration task to create the versioned table using options passed to acts_as_versioned
          def create_versioned_table(create_table_options = {})
            puts "Creating tables for #{self.to_s}"
            belongs_to_associations = self.reflect_on_all_associations(:belongs_to).reject{|association| association.name == :versions}
            belongs_to_associations.each do |association|
              unless ActiveRecord::Base.connection.columns(table_name).any?{|c| c.name=="#{association.name.to_s}_version"}
               self.connection.add_column table_name, "#{association.name.to_s}_version", :integer
              end
            end
            
            has_and_belongs_to_many_associations = self.reflect_on_all_associations(:has_and_belongs_to_many)
            has_and_belongs_to_many_associations.each do |association|
              
              #add version columns to join table
              unless ActiveRecord::Base.connection.columns(association.options[:join_table]).any?{|c| c.name=="#{self.to_s.underscore}_version"}
               self.connection.add_column association.options[:join_table], "#{self.to_s.underscore}_version", :integer
              end
              
              #create version table for join table if it does not exist
              join_version_table_name = "#{association.options[:join_table]}_versions"
              if connection.table_exists?(join_version_table_name)
                unless ActiveRecord::Base.connection.columns(join_version_table_name).any?{|c| c.name=="#{self.to_s.underscore}_version"}
                  self.connection.add_column join_version_table_name, "#{self.to_s.underscore}_version", :integer
                end
              else
                columns = self.connection.columns(association.options[:join_table])
                self.connection.create_table(join_version_table_name, {:id => false}) do |t|
                  columns.each do |col|
                    t.column col.name, col.type,
                      :limit     => col.limit, 
                      :default   => col.default,
                      :scale     => col.scale,
                      :precision => col.precision
                  end
                end
              end
              
            end
            
            # create version column in main table if it does not exist
            if !self.content_columns.find { |c| [version_column.to_s, 'lock_version'].include? c.name }
              self.connection.add_column table_name, version_column, :integer
              self.reset_column_information
            end

            return if connection.table_exists?(versioned_table_name)
            
            self.connection.create_table(versioned_table_name, create_table_options) do |t|
              t.column versioned_foreign_key, :integer
              t.column version_column, :integer
            end

            self.versioned_columns.each do |col| 
                self.connection.add_column versioned_table_name, col.name, col.type, 
                  :limit     => col.limit, 
                  :default   => col.default,
                  :scale     => col.scale,
                  :precision => col.precision
            end

            if type_col = self.columns_hash[inheritance_column]
                self.connection.add_column versioned_table_name, versioned_inheritance_column, type_col.type, 
                  :limit     => type_col.limit, 
                  :default   => type_col.default,
                  :scale     => type_col.scale,
                  :precision => type_col.precision
            end
            
            self.connection.add_index versioned_table_name, versioned_foreign_key
          end

          # Rake migration task to drop the versioned table
          def drop_versioned_table
            self.connection.drop_table versioned_table_name
          end

          # Executes the block with the versioning callbacks disabled.
          #
          #   Foo.without_revision do
          #     @foo.save
          #   end
          #
          def without_revision(&block)
            class_eval do 
              CALLBACKS.each do |attr_name|
                alias_method "orig_#{attr_name}".to_sym, attr_name
                alias_method attr_name, :empty_callback
              end
            end
            block.call
          ensure
            class_eval do 
              CALLBACKS.each do |attr_name|
                alias_method attr_name, "orig_#{attr_name}".to_sym
              end
            end
          end

          # Turns off optimistic locking for the duration of the block
          #
          #   Foo.without_locking do
          #     @foo.save
          #   end
          #
          def without_locking(&block)
            current = ActiveRecord::Base.lock_optimistically
            ActiveRecord::Base.lock_optimistically = false if current
            begin
              block.call
            ensure
              ActiveRecord::Base.lock_optimistically = true if current
            end
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::Versioned