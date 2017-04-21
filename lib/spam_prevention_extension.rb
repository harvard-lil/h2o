module SpamPreventionExtension
  extend ActiveSupport::Concern

  included do
    attr_accessor :spam_prevention
    # validate :spam_check
  end

  def spam_check
    if defined?(Rails::Console)
      logger.warn 'WARNING: Skipping user verification because Rails::Console is defined' and return
    end
    if current_user && !current_user.preverified?
      if self.description.to_s.downcase.split(/<\/a>/).size > 20
        self.errors.add(:base, "Sorry, we could not #{self.new_record? ? "create" : "update"} your item.")
      end
    end
  end

  # To find all failed: Playlist.all.inject([]) { |arr, p| arr << p.id if p.description.to_s.downcase.split(/<\/a>/).size > 20; arr }
end
