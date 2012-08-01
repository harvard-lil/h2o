module RedclothExtensions
  module ClassMethods
    def format_content(*args)
      doc = RedCloth.new(args.join(' '))
      doc.sanitize_html = false
      doc.filter_styles = false
      doc.filter_classes = false
      doc.filter_ids = false
      output = ActionController::Base.helpers.sanitize(
        doc.to_html,
        :tags => WHITELISTED_TAGS,
        :attributes => WHITELISTED_ATTRIBUTES
      )
      if output.scan('<p>').length == 1
        # A single <p> tag. Get rid of it.
        if output[0..2] == "<p>" then output = output[3..-1] end
        if output[-4..-1] == "</p>" then output = output[0..-5] end
      end
      output
    end

    def format_html(*args)
      logger.warn(args.join)
      ActionController::Base.helpers.sanitize(
        args.join(' '),
        :tags => WHITELISTED_TAGS, 
        :attributes => WHITELISTED_ATTRIBUTES
      )
    end
  end
end
