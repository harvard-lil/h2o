class RawContent < ApplicationRecord
  belongs_to :source, polymorphic: true

  def sanitized_content
    HTMLHelpers::parse_and_process_nodes(content).to_html
  end
end
