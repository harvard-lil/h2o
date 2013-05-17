ActiveRecord::Reflection::AssociationReflection.class_eval do
  def polymorphic?    
    (self.options.has_key?(:as)) || (self.options.has_key?(:polymorphic) and self.options[:polymorphic] == true)
  end
  
  def polymorphic_name
    if self.options.has_key?(:as)
      self.options[:as]
    else
      self.name
    end
  end
end