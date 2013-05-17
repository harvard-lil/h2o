class ActiveRecord::Base

  def self.insert_column_names
    self.columns.reject{|col| col.name == "id"}.map(&:name)
  end

  def self.insert_value_names(options = {})
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

Array.class_eval do
  def to_insert_value_s
    res = self.map{|value| ActiveRecord::Base.connection.quote(value)}
    res = "(#{res.join(", ")})"
    res
  end
end

