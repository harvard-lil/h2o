require 'tagging_extensions'
require 'redcloth_extensions'
require 'ancestry_extensions'

class Playlist < ActiveRecord::Base
  extend AncestryExtensions::ClassMethods
  extend RedclothExtensions::ClassMethods

  include PlaylistableExtensions
  include AncestryExtensions::InstanceMethods
  include TaggingExtensions::InstanceMethods
  include AuthUtilities

  named_scope :public, :conditions => {:public => true, :active => true}

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict
  #no sql injection here.
  acts_as_list :scope => 'ancestry = #{self.connection.quote(self.ancestry)}'

  acts_as_authorization_object
  acts_as_taggable_on :tags

  searchable(:include => [:tags]) do
    text :display_name
    string :display_name, :stored => true
    string :id, :stored => true
    text :description
    text :name
	string :tag_list, :stored => true, :multiple => true
	text :author

    boolean :public
	time :created_at
  end

  #has_many :playlist_items, :order => :position
  has_many :playlist_items, :order => "playlist_items.position", :dependent => :destroy
  has_many :roles, :as => :authorizable, :dependent => :destroy

  validates_presence_of :name
  validates_length_of :name, :in => 1..250

  def author
    owner = self.accepted_roles.find_by_name('owner')
	owner.nil? ? nil : owner.user
  end

  def display_name
    owners = self.accepted_roles.find_by_name('owner')
    "\"#{self.name}\",  #{self.created_at.to_s(:simpledatetime)} #{(owners.blank?) ? '' : ' by ' + owners.users.collect{|u| u.login}.join(',')}"
  end

  alias :to_s :display_name
end
