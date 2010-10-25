module H2oModelExtensions

  def self.included(model)

    model.class_eval do
      # Instance methods go here.
      validate do |rec|
        # Validate text and string column lengths automatically, and for existence.
        to_validate = rec.class.columns.reject{|col| ! [:string,:text].include?(col.type)}
        to_validate.each do|val_col|
          validates_length_of val_col.name.to_sym, :maximum => val_col.limit, :allow_blank => val_col.null
          if ! val_col.null
            validates_presence_of val_col.name.to_sym
          end
        end
      end
    end

    model.instance_eval do
      #Class methods go here.
      def yuppers
        'yup'
      end
    end

  end

end