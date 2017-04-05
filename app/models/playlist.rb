# == Schema Information
#
# Table name: playlists
#
#  id                 :integer          not null, primary key
#  name               :string(1024)
#  description        :text
#  created_at         :datetime
#  updated_at         :datetime
#  public             :boolean          default(TRUE)
#  ancestry           :string(255)
#  position           :integer
#  counter_start      :integer          default(1), not null
#  karma              :integer
#  pushed_from_id     :integer
#  location_id        :integer
#  when_taught        :string(255)
#  user_id            :integer          default(0), not null
#  primary            :boolean          default(FALSE), not null
#  featured           :boolean          default(FALSE), not null
#  created_via_import :boolean          default(FALSE), not null
#

class Playlist < ApplicationRecord
  include StandardModelExtensions
  include AncestryExtensions
  include CaptchaExtensions
  include VerifiedUserExtensions
  include SpamPreventionExtension
  include DeletedItemExtensions
  include Rails.application.routes.url_helpers

  RATINGS_DISPLAY = {
    :clone => "Cloned",
    :bookmark => "Bookmarked",
    :add => "Added to another playlist"
  }

  acts_as_taggable_on :tags

  has_ancestry :orphan_strategy => :adopt

  has_many :playlist_items, -> { order("playlist_items.position") }, :dependent => :destroy
  has_many :roles, :as => :authorizable, :dependent => :destroy
  has_and_belongs_to_many :user_collections, :dependent => :destroy
  belongs_to :location, optional: true
  belongs_to :user
  has_many :playlist_items_as_actual_object, :as => :actual_object, :class_name => "PlaylistItem"

  validates_presence_of :name
  validates_length_of :name, :in => 1..250

  before_destroy :collapse_children

  validate :when_taught_validation

  # For Rails Admin delete purposes only
  def playlists_user_collections
    []
  end

  def when_taught_validation
    self.when_taught = self.when_taught.to_s.downcase.gsub(/ /, '')

    # return if empty
    return if self.when_taught == ""

    # return if "other"
    return if self.when_taught == "other"

    # return if match on year 20**
    return if self.when_taught.match(/^20\d{2}$/).present?

    # return if match on year range 20**-20**
    return if self.when_taught.match(/^20\d{2}-20\d{2}$/).present?

    # return if match on comma delimited years, 20**(,20**)
    return if self.when_taught.match(/^20\d{2}(,20\d{2})+$/).present?

    # return if match on semester, or month, plus year
    if self.when_taught.match(/^(spring|summer|fall|winter|january|february|march|april|may|june|july|august|september|october|november|december)(20\d{2})?$/).present?
      if $2.present?
        self.when_taught = "#{$1} #{$2}"
      end
      return
    end

    errors.add(:when_taught, "is not valid. Please read instructiosn below to learn valid options.")
  end

  searchable(:include => [:tags], :if => :not_bookmark?) do
    text :display_name
    string :display_name, :stored => true
    string :id, :stored => true
    text :description
    text :name
    string :tag_list, :stored => true, :multiple => true
    string :user
    string :user_display, :stored => true
    integer :user_id, :stored => true
    string :root_user_display, :stored => true
    integer :root_user_id, :stored => true
    integer :karma
    string :users_by_permission, :stored => true, :multiple => true

    boolean :featured
    boolean :public
    boolean :primary
    boolean :secondary

    time :created_at
    time :updated_at

    string :klass, :stored => true
  end

  def not_bookmark?
    self.name != "Your Bookmarks"
  end

  def display_name
    "\"#{self.name}\",  #{self.created_at.to_s(:simpledatetime)}" + (self.user ? " by " + self.user.login : "")
  end
  alias :to_s :display_name

  def secondary
    !self.primary
  end

  def parents
    PlaylistItem.unscoped.where(actual_object_id: self.id, actual_object_type: "Playlist").collect { |p| p.playlist }.uniq
  end

  def relation_ids
    r = self.parents
    i = 0
    while i < r.size
      Playlist.where(id: r[i]).first.parents.each do |a|
        next if r.include?(a) || a.name == "Your Bookmarks"
        r.push(a)
      end
      i+=1
    end

    r.collect { |p| p.id }
  end

  def actual_objects
    self.playlist_items.map(&:actual_object)
  end

  def collage_word_count
    shown_word_count = 0
    total_word_count = 0
    self.playlist_items.each do |pi|
      if pi.actual_object_type == 'Collage' && pi.actual_object
        shown_word_count += pi.actual_object.words_shown.to_i
        total_word_count += (pi.actual_object.word_count.to_i-1)
      elsif pi.actual_object_type == 'Playlist' && pi.actual_object && pi.actual_object != self
        res = pi.actual_object.collage_word_count
        shown_word_count += res[0]
        total_word_count += res[1]
      end
    end
    [shown_word_count, total_word_count]
  end

  def all_actual_object_ids
    t = { :Collage => [], :Playlist => [], :Default => [], :Case => [], :TextBlock => [] }
    self.playlist_items.each do |pi|
      t[pi.actual_object_type.to_sym] << pi.actual_object.id if pi.actual_object.present?
      if pi.actual_object_type == "Playlist" && pi.actual_object.present?
        b = pi.actual_object.all_actual_object_ids
        t.each { |k, v| t[k] = t[k] + b[k] }
      end
    end
    t
  end

  def all_actual_items
    t = []
    self.playlist_items.each do |pi|
      t << pi.actual_object if pi.actual_object.present?
      if pi.actual_object_type == "Playlist" && pi.actual_object.present?
        pi.actual_object.all_actual_items.each do |b|
          t << b
        end
      end
    end
    t
  end

  def contains_item?(item_key)
    self.playlist_items.map { |pi| "#{pi.actual_object_type}#{pi.actual_object_id}" }.include?(item_key)
  end

  def push!(options = {})
    if options[:recipient]
      push_to_recipient!(options[:recipient])
    elsif options[:recipients]
      options[:recipients].each do |r|
        push_to_recipient!(r)
      end
    else
      false
    end
  end

  def public_count
    self.playlist_items.select { |pi| pi.public_notes }.count
  end

  def private_count
    self.playlist_items.select { |pi| !pi.public_notes }.count
  end

  def total_count
    self.playlist_items.count
  end

  def nested_private_resources
    results = []
    self.playlist_items.each do |item|
      if item.actual_object && !item.actual_object.public
        results << item.actual_object
      end
      if item.actual_object_type == "Playlist" && item.actual_object
        results << item.actual_object.nested_private_resources
      end
    end
    return results.flatten
  end

  def self.destroy_playlist_and_nested(playlist)
    all_nested_items = playlist.all_actual_items
    items = []

    all_nested_items.each do |item|
      can_delete = item.user == playlist.user

      if [Collage, Default, TextBlock].include?(item.class)
        playlist_users = item.playlist_items.collect { |pi| pi.playlist.user_id }.uniq
        if playlist_users.detect { |u| u != playlist.user_id }
          can_delete = false
          item.update_attributes({ :user_id => 101022 })
        end
      end

      if can_delete
        item.destroy
        items << "<b>#{item.class.to_s}:</b> #{item.name}"
      end
    end

    playlist.destroy

    return "Playlist #{playlist.name} and nested items have been deleted."
  end

  def toggle_nested_private
    self.nested_private_resources.select { |i| i.user_id == self.user_id }.each do |item|
      item.update_attribute(:public, true)
    end
  end

  def users_by_permission
    # Temporary override on users by permissions
    return []

    if self.name == "Your Bookmarks" || self.public
      return []
    end

    # TODO: Figure out a better way to do this logic, or cache, and sweep
    p = Permission.where(key: "view_private")
    pas = self.user_collections.collect { |uc| uc.permission_assignments }.flatten.select { |pr| pr.permission_id = p.id }
    ( pas.collect { |pr| pr.user }.flatten.collect { |u| u.login } + [self.user.login] ).flatten.uniq
  end

  def self.clear_nonsiblings(id)
    record = PlaylistItem.unscoped { Playlist.where(id: id) }.first

    ActionController::Base.expire_page "/playlists/#{record.id}.html"
    ActionController::Base.expire_page "/playlists/#{record.id}/export.html"
    record.relation_ids.each do |p|
      ActionController::Base.expire_page "/playlists/#{p}.html"
      ActionController::Base.expire_page "/playlists/#{p}/export.html"
    end
  end

  def h2o_clone(new_user, params)
    playlist_copy = self.dup
    playlist_copy.parent = self
    playlist_copy.name = params[:name] if params.has_key?(:name)
    playlist_copy.public = params[:public] if params.has_key?(:public)
    playlist_copy.description = params[:description] if params.has_key?(:description)
    playlist_copy.created_at = Time.now
    playlist_copy.karma = 0
    playlist_copy.user = new_user
    playlist_copy.featured = false

    self.playlist_items.each do |playlist_item|
      new_playlist_item = playlist_item.dup
      playlist_copy.playlist_items << new_playlist_item
    end

    playlist_copy
  end

  def clear_page_cache
    Rails.logger.debug "Firing for playlist id: #{id}"
    begin
      ActionController::Base.expire_page "/playlists/#{id}.html"
      ActionController::Base.expire_page "/playlists/#{id}/export.html"
      ActionController::Base.expire_page "/iframe/load/playlists/#{id}.html"
      ActionController::Base.expire_page "/iframe/show/playlists/#{id}.html"

      relation_ids.each do |p|
        ActionController::Base.expire_page "/playlists/#{p}.html"
        ActionController::Base.expire_page "/playlists/#{p}/export.html"
        ActionController::Base.expire_page "/iframe/load/playlists/#{p}.html"
        ActionController::Base.expire_page "/iframe/show/playlists/#{p}.html"
      end

      if saved_changes.keys.include?(:public)
        [:playlists, :collages, :cases].each do |type|
          user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
        end
        [:playlists, :collages].each do |type|
          user.send(type).each do |i|
            ActionController::Base.expire_page "/iframe/load/#{type.to_s}/#{i.id}.html"
            ActionController::Base.expire_page "/iframe/show/#{type.to_s}/#{i.id}.html"
          end
        end
        user.collages.update_all(updated_at: Time.now)
      end
    rescue Exception => e
      Rails.logger.warn "Playlist sweeper error: #{e.inspect}"
    end
  end

end
