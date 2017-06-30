module Export::PDF
  class ExportException < StandardError; end
  def self.logger; Rails.logger; end

  def self.save html, annotations: true
    html_path = save_html html
    convert_to_pdf html_path, annotations: annotations
  end

  private

  def self.convert_to_pdf in_path, annotations:
    command = pdf_command(in_path, annotations: annotations)
    out_path = command.last
    logger.debug "Running PDF generation: #{command.inspect} #{command.shelljoin}"

    if system command.shelljoin + " >> #{Rails.root.join 'log/wkhtmltopdf.log'} 2>&1"
      if Rails.env == 'test'
        # Remove creation date for deterministic tests
        IO.binwrite(out_path, File.open(out_path, 'r:ASCII-8BIT') {|f| f.read.sub /\/CreationDate \(D:[^)]*\)/, '' })
      end
      return out_path
    else
      raise ExportException, $?.inspect
    end
  end

  def self.pdf_command(in_path, annotations: true)  #_pdf
    #request_url is the full request URI that is posting TO this page. We need
    # pieces of that that to construct the URL we are going to pass to wkhtmltopdf
    options = [
      '--encoding', 'utf-8'
    ]
    if annotations
      options += ['--user-style-sheet', Rails.root.join('app/assets/stylesheets/export/with-annotations.css')]
    else
      options += ['--user-style-sheet', Rails.root.join('app/assets/stylesheets/export/no-annotations.css')]
    end
    # %w[margin-top margin-right margin-bottom margin-left].map {|name|
    #   %W{--#{name} #{params[name]}}
    # }.flatten

    out_path = Rails.root.join "tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.pdf"

    [
      'wkhtmltopdf',
      *options,
      in_path,
      out_path,  #This always has to be last in this array
    ]
  end

  def self.save_html html
      out_path = Rails.root.join "tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.html"
      File.write out_path, html
      out_path
  end
end
