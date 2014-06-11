module VerifiedUserExtensions
  extend ActiveSupport::Concern

  included do
    attr_accessor :verified_user
    validate :verify_user, :if => Proc.new { |f| f.new_record? }
  end
  
  def verify_user
    if !current_user.verified
      self.errors.add(:base, "Your account must be verified to contribute to H2O.")
    end
  end
end
