class Playlist < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include StandardModelExtensions::InstanceMethods
  include AncestryExtensions::InstanceMethods
  include AuthUtilities
  include Authorship
  include KarmaRounding
  include ActionController::UrlWriter

  RATINGS = {
    :remix => 5,
    :bookmark => 1,
    :add => 3
  }
  RATINGS_DISPLAY = {
    :remix => "Remixed",
    :bookmark => "Bookmarked",
    :add => "Added to another playlist"
  }

  #no sql injection here.
  acts_as_list :scope => 'ancestry = #{self.connection.quote(self.ancestry)}'
  acts_as_authorization_object
  acts_as_taggable_on :tags

  has_ancestry :orphan_strategy => :restrict

  has_many :playlist_items, :order => "playlist_items.position", :dependent => :destroy
  has_many :roles, :as => :authorizable, :dependent => :destroy
  has_and_belongs_to_many :user_collections #, :dependent => :destroy
  belongs_to :location
  belongs_to :user
  has_many :playlist_items_as_actual_object, :as => :actual_object, :class_name => "PlaylistItem"

  validates_presence_of :name
  validates_length_of :name, :in => 1..250

  before_destroy :collapse_children
  named_scope :public, :conditions => {:public => true, :active => true}

  validate :when_taught_validation

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

  searchable(:include => [:tags]) do
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

    boolean :public
    boolean :active

    time :created_at
    time :updated_at
  end

  def display_name
    "\"#{self.name}\",  #{self.created_at.to_s(:simpledatetime)}" + (self.user ? " by " + self.user.login : "")
  end
  alias :to_s :display_name

  def barcode
    Rails.cache.fetch("playlist-barcode-#{self.id}") do
      barcode_elements = self.barcode_bookmarked_added
      self.public_children.each do |child|
        barcode_elements << { :type => "remix",
                              :date => child.created_at,
                              :title => "Remixed to Playlist #{child.name}",
                              :link => playlist_path(child.id) }
      end

      value = barcode_elements.inject(0) { |sum, item| sum += self.class::RATINGS[item[:type].to_sym].to_i; sum }
      self.update_attribute(:karma, value)

      barcode_elements.sort_by { |a| a[:date] }
    end
  end

  def parents
    PlaylistItem.find_all_by_actual_object_id_and_actual_object_type(self.id, "Playlist").collect { |p| p.playlist_id }.uniq
  end

  def relation_ids
    r = self.parents
    i = 0
    while i < r.size
      Playlist.find(r[i]).parents.each do |a|
        next if r.include?(a)
        r.push(a)
      end
      i+=1
    end
    r
  end

  def actual_objects
    self.playlist_items.map(&:actual_object)
  end

  def child_playlists
    self.actual_objects.find_all{ |ao| ao.class == Playlist }
  end

  def collage_word_count
    Rails.cache.fetch("playlist-wordcount-#{self.id}") do
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

  def reset_positions
    self.playlist_items.each_with_index do |pi, index|
      pi.update_attribute(:position, self.counter_start + index)
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

  def toggle_nested_private
    self.nested_private_resources.select { |i| i.user_id == self.user_id }.each do |item|
      item.update_attribute(:public, true)
    end
  end

  def users_by_permission
    if self.name == "Your Bookmarks" || self.public
      return []
    end

    # TODO: Figure out a better way to do this logic, or cache, and sweep
    p = Permission.find_by_key("view_private")
    pas = self.user_collections.collect { |uc| uc.permission_assignments }.flatten.select { |pr| pr.permission_id = p.id }
    ( pas.collect { |pr| pr.user }.flatten.collect { |u| u.login } + [self.user.login] ).flatten.uniq
  end

  private

  def recursive_playlists(playlist)
    yield playlist
    playlist.actual_objects.find_all{|ao| ao.is_a?(Playlist)}.each do |child|
      recursive_playlists(child){|x| yield x}
    end
  end
end
