class PlaylistPusher
  attr_reader :user_ids,
              :source_playlist_id,
              :email_receiver,
              :playlist_name_override,
              :public_private_override,
              :barcode_clear_users
  attr_accessor :ownership_sql,
              :public_private_sql

  def initialize(options = {})
    @user_ids = options[:user_ids]
    @source_playlist_id = options[:playlist_id]
    @email_receiver = options.has_key?(:email_receiver) ? options[:email_receiver] : 'source'
    @ownership_sql = ''
    @public_private_sql = ''
    @barcode_clear_users = []
    @created_playlist_ids = []
    if options.has_key?(:playlist_name_override)
      @playlist_name_override = options[:playlist_name_override]
    end
    if options.has_key?(:public_private_override)
      @public_private_override = options[:public_private_override] == "1" ? true : false
    else
      @public_private_override = nil
    end
  end

  def push!
    new_playlists = self.push_single_playlist(self.source_playlist_id, 0)
    execute!(self.ownership_sql)
    execute!(self.public_private_sql)
    self.barcode_clear_users.uniq.each do |user|
      Rails.cache.delete("user-barcode-#{user.id}") 
      Rails.cache.delete("views/user-barcode-html-#{user.id}")
      #user.update_karma #Causes major performance issues
    end

    if @playlist_name_override && self.user_ids.length == 1
      new_playlists.first.update_attribute(:name, @playlist_name_override)
    end

    self.notify_completed(new_playlists)
  end

  def push_single_playlist(new_source_playlist_id, recursive_level)
    source_playlist = Playlist.find(new_source_playlist_id)
    created_playlist_ids = execute!(self.build_playlist_sql(source_playlist))
    new_playlists = Playlist.find(created_playlist_ids)
    self.generate_ownership_sql!(new_playlists)
    self.generate_public_private_sql!(new_playlists)
    self.barcode_clear_users << source_playlist.user

    return new_playlists if recursive_level > 4

    created_actual_objects = []
    source_playlist.playlist_items.each do |playlist_item|
      if playlist_item.actual_object_type == "Playlist"
        created_actual_objects << push_single_playlist(playlist_item.actual_object_id, recursive_level + 1)
      else
        created_actual_objects << create_actual_object(playlist_item.actual_object)
      end
    end
    created_actual_objects = created_actual_objects.flatten

    self.create_playlist_items!(new_playlists, source_playlist, created_actual_objects) if created_actual_objects.any?

    return new_playlists
  end

  def notify_completed(new_playlists)
    playlist = Playlist.find(self.source_playlist_id)
    if self.email_receiver == 'source'
      recipient = playlist.user
    elsif self.email_receiver == 'destination' && self.user_ids.length == 1
      recipient = new_playlists.first.user
    end
    Notifier.deliver_playlist_push_completed(recipient, playlist.name, new_playlists.first.id)
  end

  def build_playlist_sql(source_playlist)
    source_playlist = Playlist.find(self.source_playlist_id)
    @barcode_clear_users << source_playlist.user

    playlist_id = self.source_playlist_id
    sql = "INSERT INTO playlists (\"#{Playlist.insert_column_names.join('", "')}\") "
    sql += "SELECT #{Playlist.insert_value_names(:overrides => {:pushed_from_id => playlist_id, :karma => 0, :ancestry => (source_playlist.ancestry.nil? ? playlist_id : "#{source_playlist.ancestry}/#{playlist_id}") }).join(", ")} FROM playlists, users "
    sql += "WHERE playlists.id = #{playlist_id} AND users.id IN (#{self.user_ids.join(", ")}) "
    sql += "RETURNING *;"
  end

  def create_actual_object(actual_object)
    create_sql = build_struct_from_object(actual_object)
    self.barcode_clear_users << actual_object.user

    returned_object_ids = execute!(create_sql)
    created_actual_objects = actual_object.class.find(returned_object_ids)
    self.create_collage_annotations_and_links!(actual_object, created_actual_objects) if actual_object.class == Collage
    self.generate_ownership_sql!(created_actual_objects)
    self.generate_public_private_sql!(created_actual_objects)

    return created_actual_objects
  end

  def create_collage_annotations_and_links!(source_collage, new_collages)
    objects = ([source_collage].map(&:annotations) + [source_collage].map(&:collage_links)).flatten

    if objects.any?
      structs = self.build_structs_from_objects([Annotation, CollageLink], objects, new_collages)
      structs.each do |struct|
        returned_object_ids = execute!(struct.insert_sql)
        returned_objects = struct.klass.find(returned_object_ids)
        self.generate_ownership_sql!(returned_objects)
      end
    end
  end

  def create_selects_for_actual_objects(actual_objects, new_collages)
    select_statements = actual_objects.inject([]) do |arr, ao|
      tn = ao.class.table_name
      mapped_term = ao.is_a?(CollageLink) ? :host_collage_id : :collage_id
      new_collages.each do |new_collage|
        sql = "SELECT #{ao.class.insert_value_names(:overrides => {:pushed_from_id => ao.id, mapped_term => new_collage.id, :cloned => true}).join(', ')} FROM #{tn}, users
               WHERE #{tn}.id = #{ao.id} AND users.id = #{new_collage.user_id};"
        arr << sql
      end
      arr
    end

    values_sql = build_insert_values_sql(select_statements)

    build_insert_sql(actual_objects.first.class, values_sql)
  end

  def create_select_for_actual_object(actual_object)
    select_statement = ''
    table_name = actual_object.class.table_name
    if ["playlists", "collages"].include?(table_name)
      ancestry_override = actual_object.ancestry.nil? ? "#{actual_object.id}" : "#{actual_object.ancestry}/#{actual_object.id}"
      select_statement = "SELECT #{actual_object.class.insert_value_names(:overrides => {:pushed_from_id => actual_object.id, :ancestry => ancestry_override}).join(', ')} FROM #{table_name}, users
           WHERE #{table_name}.id = #{actual_object.id} AND users.id IN (#{self.user_ids.join(", ")}); "
    else
      select_statement = "SELECT #{actual_object.class.insert_value_names(:overrides => {:pushed_from_id => actual_object.id}).join(', ')} FROM #{table_name}, users
           WHERE #{table_name}.id = #{actual_object.id} AND users.id IN (#{self.user_ids.join(", ")}); "
    end

    values_sql = build_insert_values_sql([select_statement])

    build_insert_sql(actual_object.class, values_sql)
  end

  def create_playlist_items!(new_playlists, source_playlist, created_actual_objects)
    execute!(self.build_playlist_items_sql(new_playlists, source_playlist, created_actual_objects))
  end
  def build_playlist_items_sql(new_playlists, source_playlist, created_actual_objects)
    select_statements = []
    index = 0
    source_playlist.playlist_items.each do |original_playlist_item|
      new_playlists.each do |new_playlist|
        actual_object = created_actual_objects[index]
        select_statements << "SELECT #{PlaylistItem.insert_value_names(:overrides => {:actual_object_id => actual_object.id,
                                                                       :actual_object_type => actual_object.class.to_s,
                                                                       :playlist_id => new_playlist.id,
                                                                       :pushed_from_id => original_playlist_item.id}).join(', ')}
               FROM playlist_items
               WHERE playlist_items.id = #{original_playlist_item.id};"
        index+=1
      end
    end
    values_sql = build_insert_values_sql(select_statements)

    build_insert_sql(PlaylistItem, values_sql)
  end

  def build_struct_from_object(actual_object)
    self.create_select_for_actual_object(actual_object)
  end
  def build_structs_from_objects(klasses, actual_objects, new_collages)
    struct_array = klasses.inject([]) do |arr, klass|
      klass_objects = actual_objects.find_all{|ao| ao.class == klass}
      if klass_objects.any?
        struct = OpenStruct.new
        struct.klass = klass
        struct.insert_sql = self.create_selects_for_actual_objects(klass_objects, new_collages)
        arr << struct
      end 
      arr 
    end 
    struct_array.nil? ? [] : struct_array
  end

  def generate_ownership_sql!(objects)
    klass = objects.first.class.to_s.tableize
    increments = objects.size / self.user_ids.size
    i = 0 
    1.upto(increments).each do |inc|
      self.user_ids.each do |user_id|
        self.ownership_sql << "UPDATE #{klass.tableize} SET user_id = #{user_id} WHERE id = #{objects[i].id};"
        i+=1
      end
    end

    true
  end

  def generate_public_private_sql!(objects)
    return if @public_private_override.nil?

    klass = objects.first.class.to_s.tableize
    increments = objects.size / self.user_ids.size
    i = 0 
    1.upto(increments).each do |inc|
      self.user_ids.each do |user_id|
        self.public_private_sql << "UPDATE #{klass.tableize} SET public = #{@public_private_override} WHERE id = #{objects[i].id};"
        i+=1
      end
    end

    true
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
    results = results.entries.map{|entry| entry['id']}.flatten
    results
  end
end
