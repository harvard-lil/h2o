module Export::DOCX
  class ExportException < StandardError; end
  def self.logger; Rails.logger; end
end
