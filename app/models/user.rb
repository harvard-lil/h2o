class User < ApplicationRecord
  include Rails.application.routes.url_helpers

  # Obfuscate domains to avoid this file showing up on GitHub in web searches for said domains
  EMAIL_DOMAIN_BLACKLIST = [
    'ivi' + 'zx.com',
  ]

  acts_as_authentic do |c|
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
    c.login_field = :email_address
  end

  has_and_belongs_to_many :roles
  has_many :text_blocks
  has_many :defaults

  has_many :content_collaborators, class_name: 'Content::Collaborator', primary_key: :id
  has_many :casebooks, class_name: 'Content::Casebook', through: :content_collaborators, source: :content, primary_key: :id
  has_attached_file :image, styles: { medium: "300x300>", thumb: "33x33#" }, default_url: "/assets/ui/portrait-anonymous-:style.png"

  alias :textblocks :text_blocks

  attr_accessor :terms
  attr_accessor :bypass_verification

  validates_attachment_content_type :image, content_type: /\Aimage\/.*\z/
  validates_format_of :email_address, :with => /\A([^@\s]+)@((?:[-a-z0-9]+.)+[a-z]{2,})\Z/i, :allow_blank => true
  validates_inclusion_of :tz_name, :in => ActiveSupport::TimeZone::MAPPING.keys, :allow_blank => true
  validate :allowed_email_domain, if: :new_record?
  validates_presence_of :email_address
  alias_attribute :login, :email_address

  searchable :if => :not_anonymous do
    text :simple_display
    string :display_name, :stored => true
    string(:affiliation, stored: true) { affiliation }
    string(:attribution, stored: true) { attribution }
    string(:verified_professor, stored: true) { verified_professor }
    boolean :public do
      true
    end
    date :updated_at

    integer :user_id, :stored => true
    string(:klass, stored: true) { 'User' }
  end

  def allowed_email_domain
    # Rails.logger.warn "SKIPPING DOMAIN VALIDATION FOR test purposes"
    # return true
    canonical_email = email_address.to_s.downcase.strip
    if canonical_email.ends_with?(*EMAIL_DOMAIN_BLACKLIST)
      errors.add(:base, "Database connection failed: Sorry, too many clients already.")
    end

    if !canonical_email.ends_with?('.edu')
      errors.add(:email_address, I18n.t('users.edu-only-error'))
    end
  end

  def user_id
    self.id
  end

  def not_anonymous
    attribution.present?
  end

  def has_role?(role_name)
    if role_name == :case_admin
      self.roles.detect { |r| [:case_admin, :superadmin].include?(r.name.to_sym) }.present?
    else
      self.roles.detect { |r| r.name == role_name.to_s }.present?
    end
  end

  def public
    true
  end

  def users
    []
  end

  def portrait_url
    'ui/portrait-anonymous.png'
  end

  def to_s
    display_name
  end

  def anonymous_name
    "#{email_domain}\##{id}"
  end

  def email_domain
    m = email_address.match /@(.+)$/
    m.try(:[], 1) || '?.edu'
  end

  def display
    if attribution.present?
      attribution
    elsif title.present?
      title
    else
      anonymous_name
    end
  end

  def simple_display
    display
  end
  alias :display_name :simple_display

  def send_verification_request
    reset_perishable_token!
    Notifier.verification_request(self).deliver
  end

  def send_professor_verification_request_to_admin
    Notifier.professor_verification(self).deliver
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.password_reset_instructions(self).deliver
  end

  def set_password; nil; end

  def set_password=(value)
    return nil if value.blank?
    self.password = self.password_confirmation = value
  end

  def request_professor_verification!
    Notifier.request_professor_verification(self).deliver
  end

  def owned_casebook_compacted
    # drafts of published casebooks should not show up on their own, but
    # inline with the published casebook
    casebooks.where(draft_mode_of_published_casebook: nil)
  end

  def superadmin?
    admin = false

    self.roles.each do |role|
      if role.name == "superadmin"
        admin = true
      end
    end

    admin
  end

  def new_user?
    login_count <= 1
  end
end
