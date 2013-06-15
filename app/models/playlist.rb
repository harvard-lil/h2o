class Playlist < ActiveRecord::Base
  extend RedclothExtensions::ClassMethods
  extend TaggingExtensions::ClassMethods

  include StandardModelExtensions::InstanceMethods
  include AncestryExtensions::InstanceMethods
  include AuthUtilities
  include Authorship

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

  validates_presence_of :name
  validates_length_of :name, :in => 1..250

  before_destroy :collapse_children
  named_scope :public, :conditions => {:public => true, :active => true}

  searchable(:include => [:tags]) do
    text :display_name
    string :display_name, :stored => true
    string :id, :stored => true
    text :description
    text :name
    string :tag_list, :stored => true, :multiple => true
    string :author
    integer :karma
    string :users_by_permission, :stored => true, :multiple => true

    boolean :public
    boolean :active

    time :created_at
  end

  def display_name
    owners = self.accepted_roles.find_by_name('owner')
    "\"#{self.name}\",  #{self.created_at.to_s(:simpledatetime)} #{(owners.blank?) ? '' : ' by ' + owners.users.collect{|u| u.login}.join(',')}"
  end
  alias :to_s :display_name

  def parents
    ItemPlaylist.find_all_by_actual_object_id(self.id).collect { |p| p.playlist_item.playlist_id }.uniq
  end

  def barcode
    Rails.cache.fetch("playlist-barcode-#{self.id}") do
      barcode_elements = self.barcode_bookmarked_added
      self.children.each do |child|
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
    self.playlist_items.map(&:resource_item).map(&:actual_object)
  end


  def child_playlists
    self.actual_objects.find_all{|ao| ao.class == Playlist}
    #arr = []
    #recursive_playlists(self){|x| arr << x}
    #arr = arr - [self]
    #arr
  end

  def collage_word_count
    Rails.cache.fetch("playlist-wordcount-#{self.id}") do
	    shown_word_count = 0
	    total_word_count = 0
	    self.playlist_items.each do |pi|
	      if pi.resource_item_type == 'ItemCollage' && pi.resource_item.actual_object
	        shown_word_count += pi.resource_item.actual_object.words_shown.to_i
	        total_word_count += (pi.resource_item.actual_object.word_count.to_i-1)
	      elsif pi.resource_item_type == 'ItemPlaylist' && pi.resource_item.actual_object
	        res = pi.resource_item.actual_object.collage_word_count
	        shown_word_count += res[0]
	        total_word_count += res[1]
	      end
	    end
	    [shown_word_count, total_word_count]
    end
  end

  def contains_item?(item)
    actual_objects = self.playlist_items.inject([]) do |arr, pi|
      arr << pi.resource_item.actual_object if pi.resource_item && pi.resource_item.actual_object;
      arr
    end
    actual_objects.include?(item)
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

  def users_by_permission
    if self.name == "Your Bookmarks" || self.public
      return []
    end

    # TODO: Figure out a better way to do this logic, or cache, and sweep
    p = Permission.find_by_key("view_private")
    pas = self.user_collections.collect { |uc| uc.permission_assignments }.flatten.select { |pr| pr.permission_id = p.id }
    ( pas.collect { |pr| pr.user }.flatten.collect { |u| u.login } + self.owners.collect { |u| u.login } ).flatten.uniq
  end

  private

  def recursive_playlists(playlist)
    yield playlist
    playlist.actual_objects.find_all{|ao| ao.is_a?(Playlist)}.each do |child|
      recursive_playlists(child){|x| yield x}
    end
  end
end
