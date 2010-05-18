module MigrationHelpers
  def create_foreign_key(model,foreign_model,column = nil)
    if connection.adapter_name.downcase == 'postgresql'
      execute %Q|alter table #{(model.is_a?(String)) ? model : model.table_name} add foreign key (#{(column) ? column : foreign_model.name.foreign_key}) references #{foreign_model.table_name}(#{foreign_model.primary_key}) on update cascade on delete cascade|
    end
  end

  def create_acts_as_category_indexes(model)
    [:parent_id, :children_count, :ancestors_count, :descendants_count, :position, :hidden].each do |col|
      add_index model.name.tableize.to_sym, col
    end
  end
end
