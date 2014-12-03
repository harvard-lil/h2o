class PlaylistPusher
  attr_reader :user_ids,
              :source_playlist_id,
              :email_receiver,
              :playlist_name_override,
              :public_private_override,
              :barcode_clear_users
  attr_accessor :ownership_sql,
              :featured_sql,
              :all_new_objects,
              :public_private_sql

  def initialize(options = {})
    @user_ids = options[:user_ids]
    @source_playlist_id = options[:playlist_id]
    @email_receiver = options.has_key?(:email_receiver) ? options[:email_receiver] : 'source'
    @ownership_sql = ''
    @featured_sql = ''
    @public_private_sql = ''
    @barcode_clear_users = []
    @created_playlist_ids = []
    @all_new_objects = {}
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
    execute!(self.featured_sql)
    execute!(self.public_private_sql)
    self.barcode_clear_users.uniq.each do |user|
      Rails.cache.delete("user-barcode-#{user.id}", :compress => H2O_CACHE_COMPRESSION) 
      Rails.cache.delete("views/user-barcode-html-#{user.id}", :compress => H2O_CACHE_COMPRESSION)
    end

    if @playlist_name_override && self.user_ids.length == 1
      new_playlists.first.update_attribute(:name, @playlist_name_override)
    end

    puts "attempting to reindex"
    [Case, Collage, Default, Media, Playlist, TextBlock].each do |klass|
      Sunspot.index! klass.where(id: self.all_new_objects[klass])
    end

    self.notify_completed(new_playlists)
  end

  def push_single_playlist(new_source_playlist_id, recursive_level)
    source_playlist = Playlist.where(id: new_source_playlist_id).first
    created_playlist_ids = execute!(self.build_playlist_sql(source_playlist))
    new_playlists = Playlist.where(id: created_playlist_ids)
    self.generate_ownership_sql!(new_playlists)
    self.generate_public_private_sql!(new_playlists)
    self.barcode_clear_users << source_playlist.user if source_playlist.user.present?

    return new_playlists if recursive_level > 4

    created_actual_objects = []
    source_playlist.playlist_items.each do |playlist_item|
      if playlist_item.actual_object_type == "Playlist"
        created_actual_objects << push_single_playlist(playlist_item.actual_object_id, recursive_level + 1)
      else
        created_actual_objects << create_actual_object(playlist_item.actual_object) if playlist_item.actual_object.present?
      end
    end
    created_actual_objects = created_actual_objects.flatten

    self.create_playlist_items!(new_playlists, source_playlist, created_actual_objects) if created_actual_objects.any?

    return new_playlists
  end

  def notify_completed(new_playlists)
    playlist = Playlist.where(id: self.source_playlist_id).first
    if self.email_receiver == 'source'
      recipient = playlist.user
    elsif self.email_receiver == 'destination' && self.user_ids.length == 1
      recipient = User.where(id: self.user_ids.first).first
    end
    Notifier.playlist_push_completed(recipient, playlist.name, new_playlists.first.id).deliver
  end

  def build_playlist_sql(source_playlist)
    @barcode_clear_users << source_playlist.user if source_playlist.user.present?

    sql = "INSERT INTO playlists (\"#{Playlist.insert_column_names.join('", "')}\") "
    sql += "SELECT #{Playlist.insert_value_names(:overrides => {:pushed_from_id => source_playlist.id, :karma => 0, :ancestry => (source_playlist.ancestry.nil? ? source_playlist.id : "#{source_playlist.ancestry}/#{source_playlist.id}") }).join(", ")} FROM playlists, users "
    sql += "WHERE playlists.id = #{source_playlist.id} AND users.id IN (#{self.user_ids.join(", ")}) "
    sql += "RETURNING *;"
    sql
  end

  def create_actual_object(actual_object)
    create_sql = self.create_select_for_actual_object(actual_object)
    self.barcode_clear_users << actual_object.user if actual_object.user.present?

    returned_object_ids = execute!(create_sql)
    created_actual_objects = actual_object.class.where(id: returned_object_ids)
    self.create_collage_annotations_and_links!(actual_object, created_actual_objects) if actual_object.class == Collage
    self.generate_ownership_sql!(created_actual_objects)
    self.generate_public_private_sql!(created_actual_objects)

    return created_actual_objects
  end

  def create_collage_annotations_and_links!(source_collage, new_collages)
    objects = [source_collage].map(&:annotations).flatten

    if objects.any?
      structs = self.build_structs_from_objects([Annotation], objects, new_collages)
      structs.each do |struct|
        returned_object_ids = execute!(struct.insert_sql)
        returned_objects = struct.klass.where(id: returned_object_ids)
        self.generate_ownership_sql!(returned_objects)
      end
    end
  end

  def create_selects_for_actual_objects(actual_objects, new_collages)
    select_statements = actual_objects.inject([]) do |arr, ao|
      tn = ao.class.table_name
      new_collages.each do |new_collage|
        sql = "SELECT #{ao.class.insert_value_names(:overrides => {:pushed_from_id => ao.id, :collage_id => new_collage.id, :cloned => true}).join(', ')} FROM #{tn}, users
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
      if original_playlist_item.actual_object.present?
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
    end
    values_sql = build_insert_values_sql(select_statements)

    build_insert_sql(PlaylistItem, values_sql)
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
    klass = objects.first.class

    return true if klass == Annotation

    klass_table = klass == Media ? "medias" : klass.to_s.tableize
    increments = objects.size / self.user_ids.size
    i = 0
    1.upto(increments).each do |inc|
      self.user_ids.each do |user_id|
        self.ownership_sql << "UPDATE #{klass_table} SET user_id = #{user_id} WHERE id = #{objects[i].id};"
        self.featured_sql << "UPDATE #{klass_table} SET featured = false WHERE id = #{objects[i].id};" if [Collage, Playlist].include?(klass)
        self.all_new_objects[klass] ||= []
        self.all_new_objects[klass] << objects[i].id
        i+=1
      end
    end

    true
  end

  def generate_public_private_sql!(objects)
    return if @public_private_override.nil?

    klass = objects.first.class
    klass_table = klass == Media ? "medias" : klass.to_s.tableize
    increments = objects.size / self.user_ids.size
    i = 0 
    1.upto(increments).each do |inc|
      self.user_ids.each do |user_id|
        self.public_private_sql << "UPDATE #{klass_table} SET public = #{@public_private_override} WHERE id = #{objects[i].id};"
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
