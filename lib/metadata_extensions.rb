module MetadataExtensions
  def self.included(model)
    model.class_eval do
      #instance methods
    end

    model.instance_eval do 
      #class methods
      has_one :metadatum, :as => :classifiable, :dependent => :destroy
      accepts_nested_attributes_for :metadatum,
        :allow_destroy => true,
        :reject_if => :all_blank
    end
  end
end
