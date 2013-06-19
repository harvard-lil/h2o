require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def collage_clear(record)
    expire_page :controller => :collages, :action => :show, :id => record.id
    return if params && params[:action] == 'save_readable_state'

    Rails.cache.delete_matched(%r{collages-search*})
    Rails.cache.delete_matched(%r{collages-embedded-search*})

    expire_fragment "collage-all-tags"
    expire_fragment "collage-#{record.id}-index"
    expire_fragment "collage-#{record.id}-tags"
    expire_fragment "collage-#{record.id}-annotatable-content"
    expire_fragment "case-#{record.annotatable_id}-index"

    #expire fragments of my ancestors, descendants, and siblings meta
    relations = [record.path_ids, record.descendant_ids]
    relations.push(record.sibling_ids) if !record.ancestry.nil?

    record.path_ids.each do |parent_id|
      Rails.cache.delete("collage-barcode-#{parent_id}")
    end
    relations.flatten.uniq.each do |rel_id|
      expire_page :controller => :collages, :action => :show, :id => rel_id
    end

    begin
      users = (record.owners + record.creators).uniq.collect { |u| u.id }
      users.each { |u| Rails.cache.delete("user-collages-#{u}") }
      if record.changed.include?("public")
        users.each { |u| Rails.cache.delete("user-barcode-#{u}") }
      end
    rescue Exception => e
    end
  end

  def after_create(record)
    Rails.cache.delete("#{record.annotatable.class.to_s.downcase.gsub(/item/, '')}-barcode-#{record.annotatable_id}")
  end

  def after_save(record)
    collage_clear(record)
  end

  def before_destroy(record)
    collage_clear(record)
  end

  def after_collages_save_readable_state
    item_collages = ItemCollage.find(:all, :conditions => { :actual_object_id => params[:id] }, :select => :id)
    PlaylistItem.find(:all, :conditions => { :resource_item_type => 'ItemCollage', :resource_item_id => item_collages }, :select => :playlist_id).each do |pi|
      expire_page :controller => :playlists, :action => :show, :id => pi.playlist_id
      expire_page :controller => :playlists, :action => :export, :id => pi.playlist_id
    end
  end
end
