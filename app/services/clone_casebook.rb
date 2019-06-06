class CloneCasebook
  def self.perform(original_casebook)
    new(original_casebook).perform
  end

  def initialize(original_casebook)
    @original_casebook = original_casebook
  end

  def perform
    clone_resources
    clone_resource_relationships
  end

  # private

  attr_reader :original_casebook

  def clone_resources
    begin
      connection = ActiveRecord::Base.connection
      columns = original_casebook.class.column_names - %w{id casebook_id copy_of_id is_alias created_at updated_at}
      query = <<-SQL
        INSERT INTO content_nodes(#{columns.join ', '},
          copy_of_id,
          casebook_id,
          is_alias,
          created_at,
          updated_at
        )
        SELECT #{columns.join ', '},
          id,
          #{connection.quote(original_casebook.id)},
          #{connection.quote(true)},
          #{connection.quote(DateTime.now)},
          #{connection.quote(DateTime.now)}
        FROM content_nodes WHERE casebook_id=#{connection.quote(original_casebook.copy_of.id)};
      SQL
      ActiveRecord::Base.connection.execute(query)
    end
  end

  def clone_resource_relationships
    original_casebook.resources.each do |resource|
      clone_annotations(resource)
      clone_resources_resource(resource)
    end
  end

  def clone_annotations(resource)
    resource.update_attributes is_alias: false
    resource.copy_of.annotations.each do |annotation|
      new_annotation = annotation.dup
      new_annotation.update(resource: resource)
    end
  end

  def clone_resources_resource(resource)
    # this clones TextBlocks and Links
    unless resource.resource_type == 'Case'
      new_content = resource.resource.dup
      new_content.update(user_id: original_casebook.owner.id)
      resource.update(resource_id: new_content.id)
    end
  end
end
