module ContentSanitizable
  extend ActiveSupport::Concern

  included do
    has_one :raw_content, as: :source, dependent: :destroy
    before_create :build_raw_content_and_assign_sanitized
  end

  def build_raw_content_and_assign_sanitized
    build_raw_content(content: content)
    self.content = raw_content.sanitized_content
    true
  end
end
