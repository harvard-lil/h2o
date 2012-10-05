module ActsAsTaggableOnExtension
  def self.included(model)
    model.instance_eval do 
      has_many :color_mappings, :dependent => :destroy
    end
  end
end
