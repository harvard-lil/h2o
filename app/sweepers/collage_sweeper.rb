require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def collage_clear(record)
    Rails.cache.delete_matched(%r{collages-search*})
    expire_page :controller => :collages, :action => :show, :id => record.id

    expire_fragment "collage-all-tags"
    expire_fragment "collage-#{record.id}-index"
    expire_fragment "collage-#{record.id}-tags"
    expire_fragment "collage-#{record.id}-annotatable-content"
    expire_fragment "case-#{record.annotatable_id}-index"

    #expire fragments of my ancestors, descendants, and siblings meta
    relations = [record.path_ids, record.descendant_ids]
    relations.push(record.sibling_ids) if !record.ancestry.nil?
    relations.flatten.uniq.each do |rel_id|
      expire_page :controller => :collages, :action => :show, :id => rel_id
    end

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if b.user && ['owner', 'creator'].include?(b.name); arr }.uniq
    users.push(current_user.id) if current_user
    users.each { |u| Rails.cache.delete("user-collages-#{u}") }
  end

  def after_save(record)
    collage_clear(record)
  end

  def before_destroy(record)
    collage_clear(record)
  end
end
