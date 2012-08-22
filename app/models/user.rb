# == Schema Information
# Schema version: 20090828145656
#
# Table name: users
#
#  id                :integer(4)      not null, primary key
#  created_at        :datetime
#  updated_at        :datetime
#  login             :string(255)     not null
#  crypted_password  :string(255)     not null
#  password_salt     :string(255)     not null
#  persistence_token :string(255)     not null
#  login_count       :integer(4)      default(0), not null
#  last_request_at   :datetime
#  last_login_at     :datetime
#  current_login_at  :datetime
#  last_login_ip     :string(255)
#  current_login_ip  :string(255)
#

class User < ActiveRecord::Base
  acts_as_voter
  acts_as_authentic 
  acts_as_authorization_subject
  
  has_and_belongs_to_many :roles
  has_and_belongs_to_many :user_collections
  has_many :collections, :foreign_key => "owner_id", :class_name => "UserCollection"
  has_many :rotisserie_assignments
  has_many :permission_assignments, :dependent => :destroy

  validates_format_of_email :email_address, :allow_blank => true
  validates_inclusion_of :tz_name, :in => ActiveSupport::TimeZone::MAPPING.keys, :allow_blank => true

  MANAGEMENT_ROLES = ["owner", "editor", "user"]

  def to_s
    (login.match(/^anon_[a-f,\d]+/) ? 'anonymous' : login)
  end

  def cases
    #This is an alternate query, TBD if it's really faster, but now this is cached with Rails low level caching
    #Case.find_by_sql("SELECT * FROM cases WHERE id IN
    #    (SELECT DISTINCT authorizable_id FROM roles
    #        INNER JOIN roles_users ON roles.id = roles_users.role_id
    #        WHERE (roles_users.user_id = #{self.id} AND (roles.name IN ('owner','creator') AND roles.authorizable_type = 'Case')))")
    Rails.cache.fetch("user-cases-#{self.id}") do
      self.roles.find(:all, :conditions => {:authorizable_type => 'Case', :name => ['owner','creator']}).collect(&:authorizable).uniq.compact.sort_by{|a| a.updated_at}
    end
  end

  def text_blocks
    self.roles.find(:all, :conditions => {:authorizable_type => 'TextBlock', :name => ['owner','creator']}).collect(&:authorizable).uniq.compact.sort_by{|a| a.updated_at}
  end

  def collages
    #This is an alternate query, TBD if it's really faster, but now this is cached with Rails low level caching
    #Collage.find_by_sql("SELECT * FROM collages WHERE id IN
    #    (SELECT DISTINCT authorizable_id FROM roles
    #        INNER JOIN roles_users ON roles.id = roles_users.role_id
    #        WHERE (roles_users.user_id = #{self.id} AND (roles.name IN ('owner','creator') AND roles.authorizable_type = 'Collage')))")
    Rails.cache.fetch("user-collages-#{self.id}") do
      self.roles.find(:all, :conditions => {:authorizable_type => 'Collage', :name => ['owner','creator']}).collect(&:authorizable).uniq.compact.sort_by{|a| a.updated_at}
    end
  end

  def medias
    Rails.cache.fetch("user-medias-#{self.id}") do
      self.roles.find(:all, :conditions => {:authorizable_type => 'Media', :name => ['owner','creator']}).collect(&:authorizable).uniq.compact.sort_by{|a| a.updated_at}
    end
  end

  def playlists
    #This is an alternate query, TBD if it's really faster, but now this is cached with Rails low level caching
    #Playlist.find_by_sql("SELECT * FROM playlists WHERE id IN
    #    (SELECT DISTINCT authorizable_id FROM roles
    #        INNER JOIN roles_users ON roles.id = roles_users.role_id
    #        WHERE (roles_users.user_id = #{self.id} AND (roles.name IN ('owner','creator') AND roles.authorizable_type = 'Playlist')))
    #    AND id != #{self.bookmark_id}")
    Rails.cache.fetch("user-playlists-#{self.id}") do
      self.roles.find(:all, :conditions => {:authorizable_type => "Playlist", :name => ['owner','creator']}).collect(&:authorizable).uniq.compact.sort_by{|a| a.position}.select { |p| p.id != self.bookmark_id }
    end
  end

  def update_karma
    begin
      collaged_resources = (self.cases + self.medias + self.text_blocks).map(&:collages).flatten.compact
      annotated_collages = Annotation.all(:conditions => ["collage_id in (?)", self.collages.map(&:id)]).select {|a| !(a.owners || []).map(&:id).include?(self.id)} 
      forked_collages = self.collages.select { |c| c.has_children? }
      all_incorporated_collages = ItemCollage.all(:conditions => ["actual_object_id in (?)",  self.collages.map(&:id)])
      own_incorporated_collages = all_incorporated_collages.select {|c| (c.owners || []).map(&:id).include?(self.id) }
      incorporated_collages = all_incorporated_collages - own_incorporated_collages
      incorporated_playlists = ItemPlaylist.all(:conditions => ["actual_object_id in (?)",  self.playlists.map(&:id)]).select {|i| !(i.owners || []).map(&:id).include?(self.id)} 
      
      push_forked_playlists = forked_playlists = external_collage_hits = internal_collage_hits = []
      
      ratings = {
        :collaged_resources => 3, 
        :own_incorporated_collages => 3,
        :forked_collages => 2, 
        :incorporated_collages => 5, 
        :annotated_collages => 3, 
        :incorporated_playlists => 10,
        :push_forked_playlists => 1, 
        :forked_playlists => 4, 
        :internal_collage_hits => 1, 
        :external_collage_hits => 2
      }
      values = {
        :collaged_resources => collaged_resources,
        :own_incorporated_collages => own_incorporated_collages,
        :forked_collages  => forked_collages,
        :incorporated_collages => incorporated_collages,
        :annotated_collages => annotated_collages,
        :incorporated_playlists => incorporated_playlists,
        :push_forked_playlists => push_forked_playlists,
        :forked_playlists => forked_playlists,
        :internal_collage_hits => internal_collage_hits,
        :external_collage_hits => external_collage_hits 
      }
      value = ratings.map {|k,v| (values[k] || []).size * v }.inject(0) {|sum, x| sum + x }
  
      self.update_attribute(:karma, value)
    rescue Exception => e
      Rails.logger.warn "Could not update karma for #{self.inspect} with #{e.inspect}"
    end
  end

  def bookmarks
    if self.bookmark_id
      Rails.cache.fetch("user-bookmarks-#{self.id}") do
        Playlist.find(self.bookmark_id).playlist_items
      end
    else
      []
    end
  end

  def bookmarks_type(klass, item_klass)
    Rails.cache.fetch("user-bookmark-#{klass.to_s.downcase}-#{self.id}") do
      items = self.bookmark_id ? klass.find_by_sql("SELECT * FROM #{klass.to_s.tableize}
          WHERE id IN (SELECT DISTINCT ic.actual_object_id FROM playlist_items pi
            JOIN #{item_klass.to_s.tableize} ic ON pi.resource_item_id = ic.id
            WHERE pi.resource_item_type = '#{item_klass.to_s}' AND pi.playlist_id = #{self.bookmark_id})") : []
    end
  end

  def get_current_assignments(rotisserie_discussion = nil)
    assignments_array = Array.new()

    if rotisserie_discussion.nil?
      rotisserie_assignments = self.assignments
    else
      rotisserie_assignments = RotisserieAssignment.find(:all, :conditions => {:user_id =>  self.id, :round => rotisserie_discussion.current_round, :rotisserie_discussion_id => rotisserie_discussion.id })
    end

    rotisserie_assignments.each do |assignment|
        if !assignment.responded? && assignment.open?
          assignments_array << assignment
        end
    end

    return assignments_array
  end

  def is_case_admin
    self.roles.find(:all, :conditions => {:authorizable_type => nil, :name => ['admin','case_admin','superadmin']}).length > 0 
  end

  def playlists_by_permission(permission_key)
    # TODO: Add caching, caching invalidation
    permission = Permission.find_by_key(permission_key)
    return [] if permission.nil?
    self.permission_assignments.inject([]) { |arr, pa| arr << pa.user_collection.playlists if pa.permission == permission; arr }.flatten.uniq
  end

  def can_permission_playlist(permission_key, playlist)
    playlists = self.playlists_by_permission(permission_key)
    playlists.include?(playlist)
  end

  def collages_by_permission(permission_key)
    # TODO: Add caching, caching invalidation
    permission = Permission.find_by_key(permission_key)
    return [] if permission.nil?
    self.permission_assignments.inject([]) { |arr, pa| arr << pa.user_collection.collages if pa.permission == permission; arr }.flatten.uniq
  end

  def can_permission_collage(permission_key, collage)
    collages = self.collages_by_permission(permission_key)
    collages.include?(collage)
  end
end
