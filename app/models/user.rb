class User < ActiveRecord::Base
  include StandardModelExtensions
  include Rails.application.routes.url_helpers
  include CaptchaExtensions
  include DeletedItemExtensions

  acts_as_authentic do |c|
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
  end

  has_and_belongs_to_many :roles
  has_and_belongs_to_many :user_collections
  has_and_belongs_to_many :institutions 
  has_many :collections, :foreign_key => "user_id", :class_name => "UserCollection"
  has_many :permission_assignments, :dependent => :destroy
  has_many :responses # directly through user_id

  has_many :cases, :dependent => :destroy
  has_many :text_blocks, :dependent => :destroy
  has_many :collages, :dependent => :destroy
  has_many :defaults, :dependent => :destroy
  has_many :medias, :dependent => :destroy
  has_many :case_requests, :dependent => :destroy
  has_many :playlists, :dependent => :destroy
  alias :textblocks :text_blocks

  def user_responses
    r = []
    self.text_blocks.each do |t|
      r << t.responses
    end
    self.collages.each do |c|
      r << c.responses
    end
    r.flatten
  end

  # Deal with this later by replacing habtm with hm through
  def users_roles
    []
  end
  def users_user_collections
    []
  end
  def users_institutions
    []
  end

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

  def terms_validation
    errors.add(:base, "You must agree to the Terms of Service.") if self.new_record? && terms == "0"
  end

  searchable :if => :not_anonymous do
    text :login
    text :simple_display
    string :display_name, :stored => true
    text :affiliation
    integer :karma
    boolean :public do
      true
    end
    date :updated_at
   
    integer :user_id, :stored => true
    string :klass, :stored => true
  end

  def user_id
    self.id
  end

  def not_anonymous
    !self.login.match(/^anon_/).present?
  end

  def all_items
    [self.playlists + self.cases + self.collages + self.medias + self.text_blocks].flatten
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
      return attribution #"#{attribution} #{karma_display.blank? ? '' : "(#{karma_display})"}"
    else
      return login #"#{login} #{karma_display.blank? ? '' : "(#{karma_display})"}"
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
  alias :display_name :simple_display

  def pending_cases
    self.has_role?(:case_admin) ? Case.where(public: false).includes(:case_citations) : Case.where(user_id: self.id).includes(:case_citations).order(:updated_at)
  end

  def content_errors
    content = self.collages.includes(:annotations) + self.text_blocks.includes(:annotations)
    content.map {|item|
      item.annotations.select { |a| a.error || a.feedback }
    }.flatten
  end

  def bookmarks
    if self.bookmark_id
      PlaylistItem.unscoped.where(playlist_id: self.bookmark_id)
    else
      []
    end
  end

  def bookmarks_map
    Rails.cache.fetch([self, "bookmarks_map"], :compress => H2O_CACHE_COMPRESSION) do
      self.bookmarks.map { |i| "#{i.actual_object_type.to_s.underscore}#{i.actual_object_id}" }
    end
  end

  def send_verification_request
    reset_perishable_token!
    Notifier.verification_request(self).deliver
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.password_reset_instructions(self).deliver
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
                                :link => self.send(item.is_a?(Media) ? "medias_path" : "#{item.class.to_s.tableize.singularize}_path", item),
                                :rating => User::RATINGS[created_type.to_sym] }
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
                                    :link => collage_path(collage),
                                    :rating => User::RATINGS[collaged_type.to_sym] }

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
                                  :link => user_path(playlist.user),
                                  :rating => 1 }
          else
            barcode_elements << { :type => "user_#{single_type}_added",
                                  :date => ii.created_at,
                                  :title => "#{type_title} #{ii.name.gsub(/"/, '')} added to playlist #{playlist.name}",
                                  :link => playlist_path(playlist),
                                  :rating => User::RATINGS["user_#{single_type}_added".to_sym] }
          end
        end

        if ["collages", "playlists"].include?(type)
          public_items.each do |item|
            item.public_children.each do |child|
              next if child.nil? || child.user.nil? || child.user == self
              barcode_elements << { :type => "user_#{single_type}_clone",
                                    :date => child.created_at,
                                    :title => "#{item.name.gsub(/"/, '')} forked to #{child.name}",
                                    :link => self.send("#{single_type}_path", child),
                                    :rating => 2 }
            end
          end
        end
      end

      self.defaults.each do |item|
        item.public_children.each do |child|
          next if child.nil? || child.user.nil? || child.user == self
          barcode_elements << { :type => "user_default_clone",
                                :date => child.created_at,
                                :title => "#{item.name.gsub(/"/, '')} forked to #{child.name}",
                                :link => default_path(child),
                                :rating => 1 }
        end
      end
   
      # FIXME: If barcode is turned back on, fix this
      #value = self.barcode.inject(0) { |sum, item| sum + item[:rating] }
      #self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  def shared_private_playlists
    p = Permission.where(key: "view_private_playlist").first
    permission_assignments = PermissionAssignment.where(user_id: current_user.id, permission_id: p.id).includes(:user_collection => [:playlists])
    permission_assignments.collect { |pa| pa.user_collection.playlists.select { |p| !p.public } }.flatten
  end
  def shared_private_collages
    p = Permission.where(key: "view_private_collage").first
    permission_assignments = PermissionAssignment.where(user_id: current_user.id, permission_id: p.id).includes(:user_collection => [:collages])
    permission_assignments.collect { |pa| pa.user_collection.collages.select { |p| !p.public } }.flatten
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

  def custom_label_method
    "<a href=\"/users/#{self.id}\">#{self.email_address} (#{self.simple_display})</a>"
  end
    
  def preverified?
    self.email_address.match(/\.edu$/)
  end

  def set_password; nil; end

  def set_password=(value)
    return nil if value.blank?
    self.password = value
    self.password_confirmation = value
  end

end
