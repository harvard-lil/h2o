module H2oModelExtensions
  def self.included(model)
    model.instance_eval do
      #Class methods go here.
      # Validate text and string column lengths automatically, and for existence.
      to_validate = self.columns.reject{|col| ! [:string,:text].include?(col.type)}
      valid_output = ''
      to_validate.each do|val_col|
        valid_output += "validates_length_of :#{val_col.name}, :maximum => #{val_col.limit}, :allow_blank => #{val_col.null}\n"
        if ! val_col.null
          valid_output += "validates_presence_of :#{val_col.name}\n"
        end
      end

      #This seems ass-backwards, but works well.
      model.class_eval valid_output
    end
  end
end
