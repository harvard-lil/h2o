module Export::DOCX
  class ExportException < StandardError; end
  def self.logger; Rails.logger; end

  def self.save html, annotations: true
    html_path = save_html html
    convert_to_docx html_path, annotations: annotations
  end

  private

  def self.convert_to_docx(in_path, annotations:)
      out_path = Rails.root.join "tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.docx"

      env = if Rails.env == 'test'
        {'HTMLTOWORD_DETERMINISTIC' => 'true'}
      else
        {}
      end

      command = %W{htmltoword #{in_path} #{out_path}}
      if system env, command.shelljoin + " >> #{Rails.root.join 'log/htmltoword.log'} 2>&1"
        out_path
      else
        raise ExportException, $?.inspect
      end
    end

  def self.save_html html
      out_path = Rails.root.join "tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.html"
      File.write out_path, html
      out_path
  end
end
