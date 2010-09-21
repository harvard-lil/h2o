module RedclothExtensions
  module ClassMethods
    def format_content(*args)
      doc = RedCloth.new(args.join(' '))
      doc.sanitize_html = true
      doc.filter_styles = true
      doc.filter_classes = true
      doc.filter_ids = true
      output = doc.to_html
      if output.scan('<p>').length == 1
        # A single <p> tag. Get rid of it.
        if output[0..2] == "<p>" then output = output[3..-1] end
        if output[-4..-1] == "</p>" then output = output[0..-5] end
      end
      output
    end
  end
  module InstanceMethods
    def you_win
      true
    end
  end
end
