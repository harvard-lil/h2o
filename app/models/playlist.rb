require 'redcloth_extensions'
require 'ancestry_extensions'

class Playlist < ActiveRecord::Base
  extend AncestryExtensions::ClassMethods
  extend PlaylistableExtensions::ClassMethods
  extend RedclothExtensions::ClassMethods

  include PlaylistableExtensions::InstanceMethods
  include AncestryExtensions::InstanceMethods
  include AuthUtilities

  before_destroy :collapse_children
  has_ancestry :orphan_strategy => :restrict
  #no sql injection here.
  acts_as_list :scope => 'ancestry = #{self.connection.quote(self.ancestry)}'

  acts_as_authorization_object

  #has_many :playlist_items, :order => :position
  has_many :playlist_items, :order => "playlist_items.position"
  has_many :roles, :as => :authorizable

  validates_presence_of :output_text
  validates_uniqueness_of :output_text
  validates_length_of :output_text, :in => 1..250

  def display_name
    owners = self.accepted_roles.find_by_name('owner')
    "\"#{self.title}\",  #{self.created_at.to_s(:simpledatetime)} #{(owners.blank?) ? '' : ' by ' + owners.users.collect{|u| u.login}.join(',')}"
  end

end
