module ExportService

  class ExportResult

    attr_reader :content_path, :item_name, :format

    def initialize(opts={})
      @content_path = opts[:content_path]
      @item_name = opts[:item_name]
      @format = opts[:format]
    end

    def suggested_filename
      self.item_name.parameterize.underscore + '.' + self.format
    end

    def success?
      !!self.content_path
    end

    def error_message
      #TODO: Do something useful here
      "Sorry, there was an unexpected error."
    end

    def to_s
      "#{self.content_path} #{self.suggested_filename}"
    end
  end

end
