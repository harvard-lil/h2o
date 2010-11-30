module H2oModelExtensions

  def self.included(model)

    model.class_eval do
      # Instance methods go here.
    end

    model.instance_eval do
      #Class methods go here.
      # Validate text and string column lengths automatically, and for existence.
      to_validate = self.columns.reject{|col| ! [:string,:text].include?(col.type)}
      valid_output = ''
      to_validate.each do|val_col|
        #logger.warn("Auto validating: #{val_col.name}")
        valid_output += "validates_length_of :#{val_col.name}, :maximum => #{val_col.limit}, :allow_blank => #{val_col.null}\n"
        if ! val_col.null
          #logger.warn("Auto validating: #{val_col.name} for presence")
          valid_output += "validates_presence_of :#{val_col.name}\n"
        end
      end

      #logger.warn('Extra validators:' + valid_output)

      #This seems ass-backwards, but works well.
      model.class_eval valid_output

      def yuppers
        'yup'
      end
    end

  end

end
