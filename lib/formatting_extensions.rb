module FormattingExtensions
  extend ActiveSupport::Concern

  module ClassMethods
    def format_content(*args)
      doc = RedCloth.new(args.join(' '))
      doc.sanitize_html = false
      doc.filter_styles = false
      doc.filter_classes = false
      doc.filter_ids = false
      output = ActionController::Base.helpers.sanitize(
        doc.to_html,
        :tags => WHITELISTED_TAGS,
        :attributes => WHITELISTED_ATTRIBUTES
      )
      if output.scan('<p>').length == 1
        # A single <p> tag. Get rid of it.
        if output[0..2] == "<p>" then output = output[3..-1] end
        if output[-4..-1] == "</p>" then output = output[0..-5] end
      end
      output.gsub(/&#8217;/, "'")
    end

    def format_html(*args)
      ActionController::Base.helpers.sanitize(
        args.join(' '),
        :tags => WHITELISTED_TAGS, 
        :attributes => WHITELISTED_ATTRIBUTES + ["style", "name"]
      )
    end

    def insert_column_names
      self.columns.reject{|col| col.name == "id"}.map(&:name)
    end
  
    def insert_value_names(options = {})
      overrides = options[:overrides]
      table_name = options[:table_name] || self.table_name
      results = self.insert_column_names.map{|name| "#{table_name}.#{name}"}
      results[self.insert_column_names.index("updated_at")] = "\'#{Time.now.to_formatted_s(:db)}\' AS updated_at"
      results[self.insert_column_names.index("created_at")] = "\'#{Time.now.to_formatted_s(:db)}\' AS created_at"
      if overrides
        overrides.each_pair do |key, value|
          results[self.insert_column_names.index(key.to_s)] = ActiveRecord::Base.connection.quote(value)
        end
      end
      results
    end
  end
end
