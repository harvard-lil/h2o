module ExportService

  class ExportResult

    attr_reader :content_path, :playlist_name, :format

    def initialize(opts={})
      # Rails.logger.debug "BLOOP: #{opts}"
      @content_path = opts[:content_path]
      @playlist_name = opts[:playlist_name]
      @format = opts[:format]
    end

    def suggested_filename
      self.playlist_name.parameterize.underscore + '.' + self.format
    end

    def success?
      !!self.content_path
    end

    def error_message
      #TODO: Do something useful here
      "Sorry, there was an unexpected error."
    end

  end

end
