module CaptchaExtensions
  extend ActiveSupport::Concern

  included do
    attr_accessor :valid_recaptcha
    validate :captcha, :if => Proc.new { |f| f.new_record? }
  end
  
  def captcha
    return if current_user && current_user.preverified?

    if self.valid_recaptcha.nil?
      self.errors.add(:base, "Captcha failed. Please try again.")
    end
  end
end
