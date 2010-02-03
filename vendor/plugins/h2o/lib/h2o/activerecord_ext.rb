module H2o

  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    def validates_format_of_email(*attr_names)
      configuration = {:with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i }
      configuration.update(attr_names.extract_options!)
      validates_format_of(attr_names, configuration)
    end
  end

  module InstanceMethods
    def you_win
      return 'you win it!'
    end
  end

end

ActiveRecord::Base.send :include, H2o
ActiveRecord::Base.send :include, H2o::InstanceMethods
