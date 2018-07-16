module BackfillCopiedAnnotations
  class << self
    def copy
      # only for casebooks 34381 (brett) & 35359 Legislation and Regulation 2018  jgersen@law.harvard.edu
      bad_references = Content::Resource.where(is_alias: true).where(copy_of_id: nil)
      bad_references.update_all(is_alias: false)

      resources = Content::Resource.where(is_alias: true)

      resources.each do |resource|
        annotations = resource.copy_of.annotations 

        annotations.each do |annotation|
          new_annotation = annotation.dup 
          new_annotation.update(resource_id: resource.id)
        end
      end
    end
  end
end