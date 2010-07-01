module RedclothExtensions
  module ClassMethods
    def format_content(input = '')
      doc = RedCloth.new(input)
      doc.sanitize_html = true
      doc.to_html
    end
  end
  module InstanceMethods
    def you_win
      true
    end
  end
end
