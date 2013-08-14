class PlaylistPusher
  attr_reader :user_ids,
              :source_playlist_id,
              :collage_ids,
              :created_playlist_ids,
              :playlist_item_ids,
              :created_actual_objects,
              :parent_playlist
  attr_accessor :original_actual_objects,
              :original_playlist_items,
              :created_playlist_items

  def initialize(options = {})
    @user_ids = options[:user_ids]
    @source_playlist_id = options[:playlist_id]
  end

  def push!
    self.push_parent!
    self.push_children!
  end

  def push_parent!
    @parent_playlist = Playlist.find(self.source_playlist_id)
    self.push_single_playlist!
  end

  def push_children!
   created_playlists = Playlist.find(self.created_playlist_ids)
      created_playlists.first.child_playlists.each do |child_playlist|

        @source_playlist_id = child_playlist.pushed_from_id
        child_playlists_for_all_users = created_playlists.map(&:child_playlists).flatten.find_all{|pi| pi.pushed_from_id == self.source_playlist_id}
        @created_playlist_ids = child_playlists_for_all_users.map(&:id)

        self.create_actual_objects!
        self.create_playlist_items!

        grandchild_playlists_for_all_users = child_playlists_for_all_users.map(&:child_playlists).flatten
        child_playlist.child_playlists.each do |gcp|
          @source_playlist_id = gcp.pushed_from_id
          @created_playlist_ids = grandchild_playlists_for_all_users.map(&:id)
          self.create_actual_objects!
          self.create_playlist_items!

          great_grandchild_playlists_for_all_users = grandchild_playlists_for_all_users.map(&:child_playlists).flatten
          gcp.child_playlists.each do |ggcp|
            @source_playlist_id = ggcp.pushed_from_id
            @created_playlist_ids = great_grandchild_playlists_for_all_users.map(&:id)
            self.create_actual_objects!
            self.create_playlist_items!

            great_great_grandchild_playlists_for_all_users = great_grandchild_playlists_for_all_users.map(&:child_playlists).flatten
            ggcp.child_playlists.each do |gggcp|
              @source_playlist_id = gggcp.pushed_from_id
              @created_playlist_ids = great_great_grandchild_playlists_for_all_users.map(&:id)
              self.create_actual_objects!
              self.create_playlist_items!
            end
          end
        end
      end
  end

  def child_playlists
     arr = []
     recursive_playlists(self){|x| arr << x}
     arr = arr - [self]
     arr
   end


  def recursive_playlists(playlist)
    yield playlist
    playlist.actual_objects.find_all{|ao| ao.is_a?(Playlist)}.each do |child|
      recursive_playlists(child){|x| yield x}
    end
  end

  def push_single_playlist!
    self.create_playlist!
    self.create_actual_objects!
    self.create_playlist_items!
    self.notify_completed
    true
  end

  def notify_completed
    playlist = Playlist.find(self.source_playlist_id)
    sent_by = playlist.accepted_roles.find_by_name("owner").user
    Notifier.deliver_playlist_push_completed(sent_by, playlist)
  end

  def build_playlist_sql
    playlist_id = self.source_playlist_id
    sql = "INSERT INTO playlists (\"#{Playlist.insert_column_names.join('", "')}\") "
    sql += "SELECT #{Playlist.insert_value_names(:overrides => {:pushed_from_id => playlist_id, :karma => 0}).join(", ")} FROM playlists, users "
    sql += "WHERE playlists.id = #{playlist_id} AND users.id IN (#{self.user_ids.join(", ")}) "
    sql += "RETURNING *;"
  end

  def create_playlist!
    @created_playlist_ids = execute!(self.build_playlist_sql)
    playlist = Playlist.find(@created_playlist_ids)
    self.create_role_stack!(playlist)
    true
  end

  def create_actual_objects!
    @original_actual_objects = []
    @created_actual_objects = []
    structs = self.build_actual_objects_structs || []

    structs.each do |struct|
      @returned_object_ids = execute!(struct.insert_sql)
      new_objs = struct.klass.find(@returned_object_ids)

      @created_actual_objects << new_objs
      @created_actual_objects = @created_actual_objects.flatten
      self.create_role_stack!(new_objs)
      self.create_collage_annotations_and_links!(new_objs) if struct.klass == Collage

      # TODO: Add cloning for metadatum for text blocks, which is not currently cloned
    end
    true
  end

  def create_collage_annotations_and_links!(created_objects)
    collages = self.original_actual_objects.select { |ao| ao.class == Collage }

    return if collages.empty?

    objects = (collages.map(&:annotations) + collages.map(&:collage_links)).flatten
    collage_map = created_objects.inject({}) { |h, c| h[c.pushed_from_id.to_s] = c.id; h }

    if objects.any?
      structs = self.build_structs_from_objects([Annotation, CollageLink], objects, { :collage_map => collage_map })
      structs.each do |struct|
        @returned_object_ids = execute!(struct.insert_sql)
        @created_actual_objects << struct.klass.find(@returned_object_ids)
        @created_actual_objects = @created_actual_objects.flatten
        self.create_role_stack!(@created_actual_objects)
      end
    end
  end

  def create_selects_for_actual_object_class(klass, klass_objects, options)
    select_statements = []
    if options.present? && options.has_key?(:collage_map) 
      select_statements = klass_objects.inject([]) do |arr, ao|
        tn = ao.class.table_name
        mapped_term = ao.is_a?(CollageLink) ? :host_collage_id : :collage_id
        collage_id = options[:collage_map][ao.send(mapped_term).to_s]
        sql = "SELECT #{ao.class.insert_value_names(:overrides => {:pushed_from_id => ao.id, mapped_term => collage_id}).join(', ')} FROM #{tn}, users
               WHERE #{tn}.id = #{ao.id} AND users.id IN (#{self.user_ids.join(", ")}); "
        arr << sql
      end
    else
      select_statements = klass_objects.inject([]) do |arr, ao|
        tn = ao.class.table_name
        sql = "SELECT #{ao.class.insert_value_names(:overrides => {:pushed_from_id => ao.id}).join(', ')} FROM #{tn}, users
               WHERE #{tn}.id = #{ao.id} AND users.id IN (#{self.user_ids.join(", ")}); "
        arr << sql
      end
    end

    values_sql = build_insert_values_sql(select_statements)

    build_insert_sql(klass, values_sql)

  end

  def create_playlist_items!
     if self.created_actual_objects.any?
       @playlist_item_ids = execute!(self.build_playlist_items_sql)
     end
     true
   end

  def build_playlist_items_sql
    playlists = Playlist.find(self.created_playlist_ids)
    actual_objects_filtered = self.created_actual_objects.reject { |ao| [Annotation, CollageLink].include?(ao.class) }

    select_statements = []
    self.original_playlist_items.each_with_index do |original_playlist_item, i|
        actual_object = actual_objects_filtered[i]

        sql = "SELECT #{PlaylistItem.insert_value_names(:overrides => {:actual_object_id => actual_object.id,
                                                                       :actual_object_type => actual_object.class.to_s,
                                                                       :playlist_id => self.created_playlist_ids.first,
                                                                       :pushed_from_id => original_playlist_item.id}).join(', ')}
               FROM playlist_items
               WHERE playlist_items.id = #{original_playlist_item.id};"
        select_statements << sql
    end
    values_sql = build_insert_values_sql(select_statements)

    build_insert_sql(PlaylistItem, values_sql)
  end

  def build_actual_objects_structs
    playlist_id = self.source_playlist_id

    playlist = Playlist.find(playlist_id)
    playlist_items = playlist.playlist_items
    actual_objects = playlist_items.map(&:actual_object).compact.reject{|ao| !ao.pushed_from_id.nil? }
    klasses = actual_objects.map(&:class).uniq

    self.original_playlist_items = playlist_items
    self.original_actual_objects = actual_objects

    struct_array = build_structs_from_objects(klasses, actual_objects) if actual_objects.any?
  end

  def build_structs_from_objects(klasses, actual_objects, options = nil)
    struct_array = klasses.inject([]) do |arr, klass|
      klass_objects = actual_objects.find_all{|ao| ao.class == klass}
      if klass_objects.any?
        struct = OpenStruct.new
        struct.klass = klass
        struct.insert_sql = self.create_selects_for_actual_object_class(klass, klass_objects, options)
        arr << struct
      end
      arr
    end
    struct_array = [] if struct_array.nil?
    struct_array
  end


  def create_role_stack!(objects, role_names = ['owner'])
    # object_ids = objects.map(&:id)
    # object_type = objects.first.class.to_s
    klasses = objects.map(&:class).uniq
    all_role_ids = []
    klasses.each do |klass|
      role_ids = role_names.inject([]) do |arr, role_name|
         object_ids = objects.find_all{|ao| ao.class == klass}.map(&:id)
         arr << self.create_role!(:object_type => klass,
                                    :object_ids => object_ids,
                                    :role_name => role_name)
      end.flatten
      all_role_ids = all_role_ids + role_ids
    end
    #self.create_role_versions!(all_role_ids)
    self.create_role_users!(all_role_ids)
    true
  end

  def build_role_users_sql!(role_ids)
    sql = "INSERT INTO roles_users (user_id, role_id)  VALUES "
    i = 0
    sql += role_ids.inject([]) do |arr, role_id|

      arr << "(#{self.user_ids[i].to_s}, #{role_id})"
      i = (i == self.user_ids.count - 1 ? 0 : i + 1)
      arr
    end.join(", ")
    sql
  end

  def create_role_users!(role_ids)
    execute!(self.build_role_users_sql!(role_ids))
  end

  def build_role_sql(options={})
    object_type = options[:object_type]
    object_ids = options[:object_ids]
    role_name = options[:role_name]

    sql = "INSERT INTO roles (\"name\", \"authorizable_id\", \"updated_at\", \"created_at\", \"authorizable_type\") VALUES "
    sql += object_ids.inject([]) do |arr, item_id|
      arr << "('#{role_name}', #{item_id}, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}', '#{object_type}') "
    end.join(", ")
    sql += "RETURNING *;"
  end

  def create_role!(options = {})
    execute!(self.build_role_sql(options))
  end

  def build_role_versions_sql(role_ids)
    role_ids.inject('') do |sql, role_id|
      sql += "INSERT INTO role_versions (#{Role::Version.insert_column_names}) "
      sql += "SELECT roles.authorizable_version, roles.id, roles.name, roles.authorizable_id, roles.updated_at, roles.version, roles.created_at, roles.authorizable_type "
      sql += "FROM roles "
      sql += "WHERE roles.id = #{role_id}; "
    end
  end

  def create_role_versions!(role_ids)
    execute!(self.build_role_versions_sql(role_ids))
  end

  def perform
    self.push!
  end

  private

  def build_insert_sql(klass, values_sql)
    res = "INSERT INTO \"#{klass.table_name}\" (#{klass.insert_column_names.join(", ")}) VALUES "
    res += values_sql
    res += " RETURNING *; "
    res
  end

  def build_insert_values_sql(select_statements)
    sql = select_statements.inject([]) do |arr, select_statement|
      arr << get_values(select_statement)
    end.join(", ")
  end

  def get_values(sql)
    rows = ActiveRecord::Base.connection.select_rows(sql)
    rows = rows.inject([]){|arr, r| arr << r.to_insert_value_s}.join(", ")
    rows
  end

  def execute!(sql)
    results = ActiveRecord::Base.connection.execute(sql)
    results = results.entries.map{|entry| entry['id']}
    results
  end
end
