module StandardModelExtensions
  extend ActiveSupport::Concern

  def klass
    self.class.to_s
  end
  def klass_partial
    if self.class == Case
      'case_obj'
    else
      self.class.to_s.downcase
    end
  end
  def klass_sym
    if self.class == Case
      :case_obj
    else
      self.class.to_s.downcase.to_sym
    end
  end

  def current_user
    session = UserSession.find
    current_user = session && session.user
    return current_user
  end

  def stored(field)
    self.send(field)
  end

  def playlists_included_ids
    logger.warn 'Removed playlists'
  end

  def karma_display
    case karma
    when nil
      ''
    when 0
      ''
    when 1..9
      '1+'
    when 10..999
      "#{(karma.to_i/10)*10}+"
    else
      "#{(karma.to_i/100)*100}+"
    end
  end

  def user_display
    self.user.nil? ? nil : self.user.display
  end

  def root_user_display
    begin
      self.root.user.nil? ? nil : self.root.user.display
    rescue ActiveRecord::RecordNotFound
      return nil
    end
  end

  def root_user_id
    begin
      self.root.user_id
    rescue ActiveRecord::RecordNotFound
      return self.user_id
    end
  end

  def print_formatted(field)
    converted = PlaylistExportJob.new.convert_h_tags(formatted(field))
    converted.respond_to?(:xpath) ? converted.xpath("/html/body/*").to_s : converted.to_s
  end

  def formatted(field)
    doc = RedCloth.new(self.send(field).to_s)
    doc.sanitize_html = false
    doc.filter_styles = false
    doc.filter_classes = false
    doc.filter_ids = false
    output = ActionController::Base.helpers.sanitize(
      doc.to_html,
      :tags => WHITELISTED_TAGS,
      :attributes => WHITELISTED_ATTRIBUTES
      )

    # catch unicode non-breaking space sandwiched by junk html
    return '' if /^<p>[[:space:]]<br><\/p>$/.match(output)

    if output.scan('<p>').length == 1
      # A single <p> tag. Get rid of it.
      if output[0..2] == "<p>" then output = output[3..-1] end
      if output[-4..-1] == "</p>" then output = output[0..-5] end
    end

    # &#x27; are smart quotes, I *think*
    output.gsub(/(&#8217;|&#x27;)/, "'")
  end

  module ClassMethods
    def insert_column_names
      self.columns.reject{|col| col.name == "id"}.map(&:name)
    end

    def insert_value_names(options = {})
      overrides = options[:overrides]
      table_name = options[:table_name] || self.table_name
      results = self.insert_column_names.map{|name| "#{table_name}.#{name}"}
      db_time = Time.now.to_formatted_s(:db)
      results[self.insert_column_names.index("updated_at")] = "\'#{db_time}\' AS updated_at"
      results[self.insert_column_names.index("created_at")] = "\'#{db_time}\' AS created_at"
      if overrides
        overrides.each_pair do |key, value|
          results[self.insert_column_names.index(key.to_s)] = ActiveRecord::Base.connection.quote(value)
        end
      end
      results
    end
  end
end
