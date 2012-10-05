module TaggingExtensions
  module ClassMethods
    def autocomplete_for(context = :tags, query_term = nil)
      return [] if query_term.blank?
      self.find_by_sql(['select distinct(tags.name) from tags left join taggings on tags.id = taggings.tag_id where taggable_type = ? and context = ? and tags.name like ? order by tags.name',self.name,context.to_s,"#{query_term}%"]).collect{|t|t.name}
    end

    def tag_list
      Tag.find_by_sql("SELECT ts.tag_id AS id, t.name FROM taggings ts
        JOIN tags t ON ts.tag_id = t.id
        WHERE taggable_type = '#{self}'
        GROUP BY ts.tag_id, t.name
        ORDER BY COUNT(*) DESC LIMIT 25")
    end
  end

  module InstanceMethods
    def deleteable_tags
      Tag.find_by_sql("SELECT tag_id AS id FROM
        (SELECT tag_id, COUNT(*)
          FROM annotations a
          JOIN taggings t ON a.id = t.taggable_id
          WHERE t.taggable_type = 'Annotation'
          AND a.collage_id = '#{self.id}'
          GROUP BY tag_id) b
        WHERE b.count = 1").collect { |t| t.id }
    end
  end
end
