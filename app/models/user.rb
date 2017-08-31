# == Schema Information
#
# Table name: users
#
#  id                             :integer          not null, primary key
#  created_at                     :datetime
#  updated_at                     :datetime
#  login                          :string(255)
#  crypted_password               :string(255)
#  password_salt                  :string(255)
#  persistence_token              :string(255)      not null
#  login_count                    :integer          default(0), not null
#  last_request_at                :datetime
#  last_login_at                  :datetime
#  current_login_at               :datetime
#  last_login_ip                  :string(255)
#  current_login_ip               :string(255)
#  oauth_token                    :string(255)
#  oauth_secret                   :string(255)
#  email_address                  :string(255)
#  tz_name                        :string(255)
#  bookmark_id                    :integer
#  karma                          :integer
#  attribution                    :string(255)
#  perishable_token               :string(255)
#  tab_open_new_items             :boolean          default(FALSE), not null
#  default_font_size              :string(255)      default("10")
#  title                          :string(255)
#  affiliation                    :string(255)
#  url                            :string(255)
#  description                    :text
#  canvas_id                      :string(255)
#  verified                       :boolean          default(FALSE), not null
#  default_font                   :string(255)      default("futura")
#  print_titles                   :boolean          default(TRUE), not null
#  print_dates_details            :boolean          default(TRUE), not null
#  print_paragraph_numbers        :boolean          default(TRUE), not null
#  print_annotations              :boolean          default(FALSE), not null
#  print_highlights               :string(255)      default("original"), not null
#  print_font_face                :string(255)      default("dagny"), not null
#  print_font_size                :string(255)      default("small"), not null
#  default_show_comments          :boolean          default(FALSE), not null
#  default_show_paragraph_numbers :boolean          default(TRUE), not null
#  hidden_text_display            :boolean          default(FALSE), not null
#  print_links                    :boolean          default(TRUE), not null
#  toc_levels                     :string(255)      default(""), not null
#  print_export_format            :string(255)      default(""), not null
#  image_file_name                :string
#  image_content_type             :string
#  image_file_size                :integer
#  image_updated_at               :datetime
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
  has_and_belongs_to_many :institutions
  has_many :responses, :dependent => :destroy

  has_many :cases, :dependent => :destroy
  has_many :text_blocks, :dependent => :destroy
  has_many :defaults, :dependent => :destroy
  has_many :case_requests, :dependent => :destroy

  has_many :collaborations, class_name: 'Content::Collaborator', primary_key: :id
  has_many :casebooks, class_name: 'Content::Casebook', through: :collaborations, source: :content, primary_key: :id

  has_attached_file :image, styles: { medium: "300x300>", thumb: "33x33#" }, default_url: "/assets/ui/portrait-anonymous-:style.png"
  validates_attachment_content_type :image, content_type: /\Aimage\/.*\z/

  alias :textblocks :text_blocks

  after_save :send_verification_notice, :if => Proc.new {|u| u.saved_change_to_verified? && u.verified?}

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
    text :affiliation
    string(:affiliation, stored: true) { affiliation }
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
    attribution || anonymous_name
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

  # def send_verification_request_to_admin
  #   reset_perishable_token!
  #   Notifier.admin_verification_request(self).deliver
  # end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.password_reset_instructions(self).deliver
  end

  def set_password; nil; end

  def set_password=(value)
    return nil if value.blank?
    self.password = self.password_confirmation = value
  end

  private

  def send_verification_notice
    Notifier.verification_notice(self).deliver
  end
end
