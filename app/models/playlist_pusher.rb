class PlaylistPusher
  attr_reader :user_ids,
              :source_playlist_id,
              :collage_ids,
              :resource_item_ids,
              :created_playlist_ids,
              :playlist_item_ids,
              :created_actual_objects,
              :created_resource_items,
              :parent_playlist

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
    puts "pushed parent"
  end

  def push_children!
   created_playlists = Playlist.find(self.created_playlist_ids)
   puts self.created_playlist_ids
      created_playlists.first.child_playlists.each do |child_playlist|

        @source_playlist_id = child_playlist.pushed_from_id
        created_child_playlists_for_all_users = created_playlists.map(&:child_playlists).flatten.find_all{|pi| pi.pushed_from_id == self.source_playlist_id}
        @created_playlist_ids = created_child_playlists_for_all_users.map(&:id)


        self.create_actual_objects!
        self.create_resource_items!
        self.create_playlist_items!
        puts "pushed child #{child_playlist.name}"

        grandchild_playlists_for_all_users = created_child_playlists_for_all_users.map(&:child_playlists).flatten
        child_playlist.child_playlists.each do |gcp|
        puts "push grandchild object #{gcp.name}"
          @source_playlist_id = gcp.pushed_from_id
          @created_playlist_ids = grandchild_playlists_for_all_users.map(&:id)
          self.create_actual_objects!
          self.create_resource_items!
          self.create_playlist_items!
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
    self.create_resource_items!
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
    sql += "SELECT #{Playlist.insert_value_names(:overrides => {:pushed_from_id => playlist_id}).join(", ")} FROM playlists, users "
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
    @created_actual_objects = []
    structs = self.build_actual_objects_structs || []
    structs.each do |struct|
      @returned_object_ids = execute!(struct.insert_sql)
      @created_actual_objects << struct.klass.find(@returned_object_ids)
      @created_actual_objects = @created_actual_objects.flatten
      self.create_role_stack!(@created_actual_objects)
      self.create_collage_annotations_and_links!(@created_actual_objects)
    end
    true
  end

  def create_collage_annotations_and_links!(created_objects)
    playlist_id = self.source_playlist_id
    user_ids = self.user_ids
    playlist = Playlist.find(playlist_id)
    playlist_items = playlist.playlist_items
    resource_items = playlist_items.map(&:resource_item)
    actual_objects = resource_items.map(&:actual_object).compact.reject{|ao| !ao.pushed_from_id.nil?}
    collages = actual_objects.find_all{|o| o.class == Collage}
    annotations = collages.map(&:annotations)
    links = collages.map(&:collage_links)
    objects = (annotations + links).flatten
    if objects.any?
      structs = self.build_structs_from_objects([Annotation, CollageLink], objects)
      structs.each do |struct|
        @returned_object_ids = execute!(struct.insert_sql)
        @created_actual_objects << struct.klass.find(@returned_object_ids)
        @created_actual_objects = @created_actual_objects.flatten
        self.create_role_stack!(@created_actual_objects)
      end
    end
  end

  def create_selects_for_actual_object_class(klass, klass_objects)
    select_statements = klass_objects.inject([]) do |arr, ao|
        tn = ao.class.table_name
        sql = "SELECT #{ao.class.insert_value_names(:overrides => {:pushed_from_id => ao.id}).join(', ')} FROM #{tn}, users
               WHERE #{tn}.id = #{ao.id} AND users.id IN (#{user_ids.join(", ")}); "
        arr << sql
    end
    values_sql = build_insert_values_sql(select_statements)
    build_insert_sql(klass, values_sql)

  end


  def create_resource_items!
    @created_resource_items = []
    structs = self.build_resource_items_structs || []
    structs.each do |struct|
      @returned_object_ids = execute!(struct.insert_sql)
      resource_items = struct.klass.find(@returned_object_ids)
      @created_resource_items << resource_items
      self.create_role_stack!(resource_items, ['owner'])
    end
    @created_resource_items = @created_resource_items.flatten
    true
  end

  def build_resource_items_structs
    playlist_id = self.source_playlist_id

    playlist = Playlist.find(playlist_id)
    playlist_items = playlist.playlist_items
    resource_items = playlist_items.map(&:resource_item)
    actual_objects = resource_items.map(&:actual_object)
    klasses = resource_items.map(&:class).uniq

    if actual_objects.any?
      struct_array = klasses.inject([]) do |arr, klass|
        klass_objects = resource_items.find_all{|ri| ri.class == klass}
        struct = OpenStruct.new
        struct.klass = klass
        struct.insert_sql = self.create_selects_for_resource_item_class(klass, klass_objects)
        arr << struct
      end
    end
    struct_array
  end
  #
  def create_selects_for_resource_item_class(klass, klass_objects)
    resource_items = klass_objects
    actual_objects = self.created_actual_objects.find_all{|cao| cao.class.to_s == klass.to_s.gsub('Item', '')}

    select_statements = actual_objects.inject([]) do |arr, ao|
        resource_item = resource_items.detect{|ri| (ri.actual_object_id == ao.pushed_from_id) && (ri.actual_object_type == ao.class.to_s)}
        tn = resource_item.class.table_name
        sql = "SELECT #{resource_item.class.insert_value_names(:overrides => {:actual_object_type => ao.class.to_s,
                                                                   :actual_object_id => ao.id,
                                                                   :pushed_from_id => resource_item.id,
                                                                   :url => resource_item.url.gsub(/\d+$/, "#{ao.id}")}).join(', ')}
              FROM #{tn}
              WHERE #{tn}.id = #{resource_item.id};"
        arr << sql

       end
       values_sql = build_insert_values_sql(select_statements)
       build_insert_sql(klass, values_sql)
     end

   def create_playlist_items!
     if self.created_resource_items.any?
       @playlist_item_ids = execute!(self.build_playlist_items_sql)
     end
     true
   end

  def build_playlist_items_sql
    playlists = Playlist.find(self.created_playlist_ids)
    resource_items = self.created_resource_items
    select_statements = resource_items.inject([]) do |arr, resource_item|
        playlist = playlists.detect{|playlist| playlist.author == resource_item.author}

        playlist_item = resource_item.class.find(resource_item.pushed_from_id).playlist_item
        tn = PlaylistItem.table_name
        sql = "SELECT #{PlaylistItem.insert_value_names(:overrides => {:resource_item_id => resource_item.id,
                                                                       :resource_item_type => resource_item.class.to_s,
                                                                       :playlist_id => playlist.id,
                                                                       :pushed_from_id => playlist_item.id}).join(', ')}
               FROM #{tn}
               WHERE #{tn}.id = #{playlist_item.id};"
        arr << sql

    end
    values_sql = build_insert_values_sql(select_statements)
    build_insert_sql(PlaylistItem, values_sql)

  end

  def build_actual_objects_structs
    playlist_id = self.source_playlist_id
    user_ids = self.user_ids

    playlist = Playlist.find(playlist_id)
    playlist_items = playlist.playlist_items
    resource_items = playlist_items.map(&:resource_item)
    actual_objects = resource_items.map(&:actual_object).compact.reject{|ao| !ao.pushed_from_id.nil?}
    klasses = actual_objects.map(&:class).uniq
    struct_array = build_structs_from_objects(klasses, actual_objects) if actual_objects.any?
  end

  def build_structs_from_objects(klasses, actual_objects)
    struct_array = klasses.inject([]) do |arr, klass|
      klass_objects = actual_objects.find_all{|ao| ao.class == klass}
      puts klass_objects.map{|ao| "#{ao.class.to_s} #{ao.id}"}.inspect unless klass == CollageLink
      if klass_objects.any?
        struct = OpenStruct.new
        struct.klass = klass
        struct.insert_sql = self.create_selects_for_actual_object_class(klass, klass_objects)
        arr << struct
      end
    end
    struct_array = [] if struct_array.nil?
    struct_array
  end


  def create_role_stack!(objects, role_names = ['owner'])
    user_ids = self.user_ids
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
    self.create_role_users!(all_role_ids, user_ids)
    true
  end

  def build_role_users_sql!(role_ids, user_ids)
    sql = "INSERT INTO roles_users (user_id, role_id)  VALUES "
    i = 0
    sql += role_ids.inject([]) do |arr, role_id|

      arr << "(#{user_ids[i].to_s}, #{role_id})"
      i = (i == user_ids.count - 1 ? 0 : i + 1)
      arr
    end.join(", ")
    sql
  end

  def create_role_users!(role_ids, user_ids)
    execute!(self.build_role_users_sql!(role_ids, user_ids))
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
