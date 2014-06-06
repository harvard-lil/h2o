class User < ActiveRecord::Base
  include StandardModelExtensions
  include Rails.application.routes.url_helpers
  include CaptchaExtensions

  acts_as_authentic do |c|
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
  end

  has_and_belongs_to_many :roles
  has_and_belongs_to_many :user_collections
  has_many :collections, :foreign_key => "owner_id", :class_name => "UserCollection"
  has_many :permission_assignments, :dependent => :destroy
  has_many :cases
  has_many :text_blocks
  has_many :collages
  has_many :defaults
  has_many :medias
  has_many :case_requests
  has_many :playlists
  alias :textblocks :text_blocks

  attr_accessor :terms

  validates_format_of :email_address, :with => /\A([^@\s]+)@((?:[-a-z0-9]+.)+[a-z]{2,})\Z/i, :allow_blank => true
  validates_inclusion_of :tz_name, :in => ActiveSupport::TimeZone::MAPPING.keys, :allow_blank => true
  validate :terms_validation

  RATINGS = {
    :playlist_created => 5,
    :collage_created => 3,
    :media_created => 1,
    :text_block_created => 1,
    :case_created => 1,
    :user_case_collaged => 3,
    :user_media_collaged => 3,
    :user_text_block_collaged => 3,
    :user_playlist_bookmarked => 1,
    :user_collage_bookmarked => 1,
    :user_case_bookmarked => 1,
    :user_media_bookmarked => 1,
    :user_text_block_bookmarked => 1,
    :user_playlist_added => 3,
    :user_collage_added => 5,
    :user_case_added => 1,
    :user_media_added => 2,
    :user_text_block_added => 2,
    :user_collage_remix => 2,
    :user_playlist_remix => 2,
    :user_default_remix => 1
  }
  RATINGS_DISPLAY = { :playlist_created => "Playlist Created",
    :collage_created => "Collage Created",
    :media_created => "Media Created",
    :text_block_created => "Text Block Created",
    :case_created => "Case Created",
    :user_case_collaged => "Case Collaged",
    :user_media_collaged => "Media Collaged",
    :user_text_block_collaged => "Text Block Collaged",
    :user_playlist_bookmarked => "Playlist Bookmarked",
    :user_collage_bookmarked => "Collage Bookmarked",
    :user_case_bookmarked => "Case Bookmarked",
    :user_media_bookmarked => "Media Bookmarked",
    :user_text_block_bookmarked => "Text Block Bookmarked",
    :user_playlist_added => "Playlist Added",
    :user_collage_added => "Collage Added",
    :user_case_added => "Case Added",
    :user_media_added => "Media Added",
    :user_text_block_added => "Text Block Added",
    :user_collage_remix => "Collage Remixed",
    :user_playlist_remix => "Playlist Remixed",
    :user_default_remix => "Link Remixed"
  }

  def terms_validation
    errors.add(:base, "You must agree to the Terms of Service.") if self.new_record? && terms == "0"
  end

  MANAGEMENT_ROLES = ["owner", "editor", "user"]

  searchable :if => :not_anonymous do
    text :login
    text :attribution
    text :affiliation
    boolean :public
    boolean :active
    boolean :anonymous
    date :updated_at
  end

  def anonymous
    self.login.match(/^anon_/).present?
  end

  def not_anonymous
    !self.anonymous
  end

  def active
    true
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

  def to_s
    (login.match(/^anon_[a-f,\d]+/) ? 'anonymous' : login)
  end

  def display
    if login.match(/^anon_[a-f,\d]+/)
      return 'anonymous'
    elsif attribution.present?
      return "#{attribution} #{karma_display.blank? ? '' : "(#{karma_display})"}"
    else
      return "#{login} #{karma_display.blank? ? '' : "(#{karma_display})"}"
    end
  end
  def simple_display
    if login.match(/^anon_[a-f,\d]+/)
      return 'anonymous'
    elsif attribution.present?
      return attribution
    else
      return login
    end
  end

  def pending_cases
    self.has_role?(:case_admin) ? Case.where(active: false) : Case.where(user_id: self.id).order(:updated_at)
  end

  def content_errors
    self.has_role?(:superadmin) ? Defect.all : []
  end

  def bookmarks
    if self.bookmark_id
      Rails.cache.fetch("user-bookmarks-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
        Playlist.where(id: self.bookmark_id).includes(:playlist_items).first.playlist_items
      end
    else
      []
    end
  end

  def bookmarks_map
    Rails.cache.fetch("user-bookmarks-map-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      self.bookmarks.map { |i| "#{i.actual_object_type.to_s.underscore}#{i.actual_object_id}" }
    end
  end

  def playlists_by_permission(permission_key)
    permission = Permission.where(key: permission_key).first
    return [] if permission.nil?
    self.permission_assignments.inject([]) { |arr, pa| arr << pa.user_collection.playlists if pa.permission == permission; arr }.flatten.uniq
  end

  def can_permission_playlist(permission_key, playlist)
    playlists = self.playlists_by_permission(permission_key)
    playlists.include?(playlist)
  end

  def collages_by_permission(permission_key)
    permission = Permission.where(key: permission_key).first
    return [] if permission.nil?
    self.permission_assignments.inject([]) { |arr, pa| arr << pa.user_collection.collages if pa.permission == permission; arr }.flatten.uniq
  end

  def can_permission_collage(permission_key, collage)
    collages = self.collages_by_permission(permission_key)
    collages.include?(collage)
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.password_reset_instructions(self).deliver
  end

  def default_font_size
    attributes['default_font_size'] || self.large_font_size
  end

  def large_font_size
    16
  end

  def save_version?
    (self.changed - self.non_versioned_columns).any?
  end

  def barcode
    Rails.cache.fetch("user-barcode-#{self.id}", :compress => H2O_CACHE_COMPRESSION) do
      barcode_elements = []

      item_types = ["collages", "playlists", "medias", "text_blocks"]
      item_types << "cases" if self.login == "h2ocases"

      item_types.each do |type|
        single_type = type.singularize
        created_type = "#{single_type}_created"
        type_title = "#{single_type.capitalize}"

        public_items = self.send(type).select { |i| i.public }

        # Base Created
        public_items.each do |item|
          barcode_elements << { :type => created_type,
                                :date => item.created_at,
                                :title => "#{item.class} created: #{item.name}",
                                :link => self.send(item.is_a?(Media) ? "medias_path" : "#{item.class.to_s.tableize.singularize}_path", item) }
        end

        # Base Collaged
        if ["cases", "text_blocks"].include?(type)
          collaged_type = "user_#{type.singularize}_collaged"
          public_items.each do |item|
            item.collages.each do |collage|
              next if collage.nil? || collage.user.nil? || collage.user == self
              barcode_elements << { :type => collaged_type,
                                    :date => collage.created_at,
                                    :title => "#{item.class} #{item.name} collaged to #{collage.name}",
                                    :link => collage_path(collage) }

            end
          end
        end

        # Bookmarked, or Incorporated
        incorporated_items = PlaylistItem.where(actual_object_id: public_items.map(&:id), actual_object_type: type_title)
        incorporated_items.each do |ii|
          next if ii.playlist.nil?
          playlist = ii.playlist
          next if playlist.user == self
          if playlist.name == "Your Bookmarks"
            barcode_elements << { :type => "user_#{single_type}_bookmarked",
                                  :date => ii.created_at,
                                  :title => "#{type_title} #{ii.name.gsub(/"/, '')} bookmarked by #{playlist.user.display}",
                                  :link => user_path(playlist.user) }
          else
            barcode_elements << { :type => "user_#{single_type}_added",
                                  :date => ii.created_at,
                                  :title => "#{type_title} #{ii.name.gsub(/"/, '')} added to playlist #{playlist.name}",
                                  :link => playlist_path(playlist) }
          end
        end

        # Remix
        if ["collages", "playlists"].include?(type)
          public_items.each do |item|
            item.public_children.each do |child|
              next if child.nil? || child.user.nil? || child.user == self
              barcode_elements << { :type => "user_#{single_type}_remix",
                                    :date => child.created_at,
                                    :title => "#{item.name.gsub(/"/, '')} forked to #{child.name}",
                                    :link => self.send("#{single_type}_path", child) }
            end
          end
        end
      end

      self.defaults.each do |item|
        item.public_children.each do |child|
          next if child.nil? || child.user.nil? || child.user == self
          barcode_elements << { :type => "user_default_remix",
                                :date => child.created_at,
                                :title => "#{item.name.gsub(/"/, '')} forked to #{child.name}",
                                :link => default_path(child) }
        end
      end

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  def update_karma
    value = self.barcode.inject(0) { |sum, item| sum += self.class::RATINGS[item[:type].to_sym].to_i; sum }
    self.update_attribute(:karma, value)
  end

  def private_playlists_by_permission
    p = Permission.where(key: "view_private").first
    pas = self.permission_assignments.select { |pa| pa.permission_id == p.id }
    playlists = pas.collect { |pa| pa.user_collection.playlists }.flatten.uniq
    playlists.select { |playlist| !playlist.public }
  end

  def has_dropbox_token?
    File.exists?(dropbox_access_token_file_path)
  end

  def dropbox_access_token_file_path
    DROPBOX_ACCESS_TOKEN_DIR + "/#{self.id.to_s}"
  end

  def has_dropbox_token?
    File.exists?(dropbox_access_token_file_path)
  end

  def dropbox_access_token
    return unless File.exists?(dropbox_access_token_file_path)
    @dropbox_access_token ||= File.read(dropbox_access_token_file_path)
  end

  def save_dropbox_access_token(token)
    delete_access_token_file_if_it_already_exists
    write_token_to_new_file(token)
  end

  def delete_access_token_file_if_it_already_exists
    FileUtils.rm_f(dropbox_access_token_file_path)
  end

  def write_token_to_new_file(token)
    File.open(dropbox_access_token_file_path, 'w') {|f| f.write(token) }
  end
end
