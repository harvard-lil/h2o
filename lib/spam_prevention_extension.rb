module SpamPreventionExtension
  extend ActiveSupport::Concern

  included do
    attr_accessor :spam_prevention
    validate :spam_check
  end
  
  def spam_check
    if current_user && !current_user.email_address.match(/edu$/)
      if self.description.to_s.downcase.split(/<\/a>/).size > 20
        self.errors.add(:base, "Sorry, we could not #{self.new_record? ? "create" : "update"} your item.")
      end
    end
  end

  # To find all failed: Playlist.all.inject([]) { |arr, p| arr << p.id if p.description.to_s.downcase.split(/<\/a>/).size > 20; arr }
end
