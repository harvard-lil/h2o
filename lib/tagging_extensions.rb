module TaggingExtensions
  module ClassMethods
    def autocomplete_for(context = :tags, query_term = nil)
      return [] if query_term.blank?
      self.find_by_sql(['select distinct(tags.name) from tags left join taggings on tags.id = taggings.tag_id where taggable_type = ? and context = ? and tags.name like ? order by tags.name',self.name,context.to_s,"#{query_term}%"]).collect{|t|t.name}
    end
  end

  module InstanceMethods
    def you_win
      return 'you win!'
    end
  end

end
