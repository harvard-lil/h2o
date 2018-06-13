# == Schema Information
#
# Table name: users
#   t.datetime "created_at"
#   t.datetime "updated_at"
#   t.string "login", limit: 255
#   t.string "crypted_password", limit: 255
#   t.string "password_salt", limit: 255
#   t.string "persistence_token", limit: 255, null: false
#   t.integer "login_count", default: 0, null: false
#   t.datetime "last_request_at"
#   t.datetime "last_login_at"
#   t.datetime "current_login_at"
#   t.string "last_login_ip", limit: 255
#   t.string "current_login_ip", limit: 255
#   t.string "oauth_token", limit: 255
#   t.string "oauth_secret", limit: 255
#   t.string "email_address", limit: 255
#   t.string "tz_name", limit: 255
#   t.integer "bookmark_id"
#   t.integer "karma"
#   t.string "attribution", limit: 255
#   t.string "perishable_token", limit: 255
#   t.boolean "tab_open_new_items", default: false, null: false
#   t.string "default_font_size", limit: 255, default: "10"
#   t.string "title", limit: 255
#   t.string "affiliation", limit: 255
#   t.string "url", limit: 255
#   t.text "description"
#   t.string "canvas_id", limit: 255
#   t.boolean "verified_email", default: false, null: false
#   t.string "default_font", limit: 255, default: "futura"
#   t.boolean "print_titles", default: true, null: false
#   t.boolean "print_dates_details", default: true, null: false
#   t.boolean "print_paragraph_numbers", default: true, null: false
#   t.boolean "print_annotations", default: false, null: false
#   t.string "print_highlights", limit: 255, default: "original", null: false
#   t.string "print_font_face", limit: 255, default: "dagny", null: false
#   t.string "print_font_size", limit: 255, default: "small", null: false
#   t.boolean "default_show_comments", default: false, null: false
#   t.boolean "default_show_paragraph_numbers", default: true, null: false
#   t.boolean "hidden_text_display", default: false, null: false
#   t.boolean "print_links", default: true, null: false
#   t.string "toc_levels", limit: 255, default: "", null: false
#   t.string "print_export_format", limit: 255, default: "", null: false
#   t.string "image_file_name"
#   t.string "image_content_type"
#   t.integer "image_file_size"
#   t.datetime "image_updated_at"
#   t.boolean "verified_professor", default: false
#   t.boolean "professor_verification_requested", default: false
#   t.index ["affiliation"], name: "index_users_on_affiliation"
#   t.index ["attribution"], name: "index_users_on_attribution"
#   t.index ["email_address"], name: "index_users_on_email_address"
#   t.index ["id"], name: "index_users_on_id"
#   t.index ["last_request_at"], name: "index_users_on_last_request_at"
#   t.index ["login"], name: "index_users_on_login"
#   t.index ["oauth_token"], name: "index_users_on_oauth_token"
#   t.index ["persistence_token"], name: "index_users_on_persistence_token"
#   t.index ["tz_name"], name: "index_users_on_tz_name"
# end
#

class User < ApplicationRecord
  include Rails.application.routes.url_helpers
  include DeletedItemExtensions

  # Obfuscate domains to avoid this file showing up on GitHub in web searches for said domains
  EMAIL_DOMAIN_BLACKLIST = [
    'ivi' + 'zx.com',
  ]

  acts_as_authentic do |c|
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
    c.login_field = :email_address
  end

  has_and_belongs_to_many :roles
  has_many :responses

  has_many :cases
  has_many :text_blocks
  has_many :defaults
  has_many :case_requests

  has_many :content_collaborators, class_name: 'Content::Collaborator', primary_key: :id
  has_many :casebooks, class_name: 'Content::Casebook', through: :content_collaborators, source: :content, primary_key: :id

  has_attached_file :image, styles: { medium: "300x300>", thumb: "33x33#" }, default_url: "/assets/ui/portrait-anonymous-:style.png"
  validates_attachment_content_type :image, content_type: /\Aimage\/.*\z/

  alias :textblocks :text_blocks

  after_save :send_verification_notice, :if => Proc.new {|u| u.saved_change_to_verified_email? && u.verified_email?}

  attr_accessor :terms
  attr_accessor :bypass_verification

  validates_format_of :email_address, :with => /\A([^@\s]+)@((?:[-a-z0-9]+.)+[a-z]{2,})\Z/i, :allow_blank => true
  validates_inclusion_of :tz_name, :in => ActiveSupport::TimeZone::MAPPING.keys, :allow_blank => true
  validate :allowed_email_domain, if: :new_record?
  validates_presence_of :email_address

  alias_attribute :login, :email_address

  RATINGS = {
    :playlist_created => 5,
    :collage_created => 3,
    :media_created => 1,
    :text_block_created => 1,
    :case_created => 1,
    :user_case_collaged => 3,
    :user_media_collaged => 3,
    :user_text_block_collaged => 3,
    :user_playlist_added => 3,
    :user_collage_added => 5,
    :user_case_added => 1,
    :user_media_added => 2,
    :user_text_block_added => 2
  }
  RATINGS_DISPLAY = { :playlist_created => "Playlist Created",
    :collage_created => "Annotated Item Created",
    :media_created => "Media Created",
    :text_block_created => "Text Block Created",
    :case_created => "Case Created",
    :user_case_collaged => "Case Annotated",
    :user_media_collaged => "Media Annotated",
    :user_text_block_collaged => "Text Block Annotated",
    :user_playlist_bookmarked => "Playlist Bookmarked",
    :user_collage_bookmarked => "Annotated Item Bookmarked",
    :user_case_bookmarked => "Case Bookmarked",
    :user_media_bookmarked => "Media Bookmarked",
    :user_text_block_bookmarked => "Text Block Bookmarked",
    :user_playlist_added => "Playlist Added",
    :user_collage_added => "Annotated Item Added",
    :user_case_added => "Case Added",
    :user_media_added => "Media Added",
    :user_text_block_added => "Text Block Added",
    :user_collage_clone => "Annotated Item Cloned",
    :user_playlist_clone => "Playlist Cloned",
    :user_default_clone => "Link Cloned"
  }

  searchable :if => :not_anonymous do
    text :simple_display
    string :display_name, :stored => true
    string(:affiliation, stored: true) { affiliation }
    string(:attribution, stored: true) { attribution }
    string(:verified_professor, stored: true) { verified_professor }
    integer :karma
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

  def all_items
    [self.cases + self.text_blocks].flatten
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

  def pending_cases
    self.has_role?(:case_admin) ? Case.where(public: false).includes(:case_citations) : Case.where(user_id: self.id).includes(:case_citations).order(:updated_at)
  end

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

  private

  def send_verification_notice
    Notifier.verification_notice(self).deliver
  end
end
