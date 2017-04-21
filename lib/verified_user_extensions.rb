module VerifiedUserExtensions
  extend ActiveSupport::Concern

  included do
    attr_accessor :verified_user
    # validate :verify_user, :if => Proc.new { |f| f.new_record? }
  end

  def verify_user
    # TODO: Checking current user here is weird.
    if defined?(Rails::Console)
      logger.warn 'WARNING: Skipping user verification because Rails::Console is defined' and return
    end
    if !(current_user && current_user.verified) && !(self.class == Playlist && self.name == "Your Bookmarks")
      self.errors.add(:base, "Your account must be verified to contribute to H2O.")
    end
  end
end
