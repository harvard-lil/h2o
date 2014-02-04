require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def collage_clear(record)
    begin
      expire_page :controller => :collages, :action => :show, :id => record.id
      return if params && params[:action] == 'save_readable_state'
 
      Rails.cache.delete_matched(%r{collages-search*})
      Rails.cache.delete_matched(%r{collages-embedded-search*})

      expire_fragment "collage-list-object-#{record.id}"

      #expire fragments of my ancestors, descendants, and siblings meta
      relations = [record.ancestor_ids, record.descendant_ids]
      relations.push(record.sibling_ids.select { |i| i != record.id }) if record.parent.present?

      record.ancestor_ids.each do |parent_id|
        Rails.cache.delete("collage-barcode-#{parent_id}")
        Rails.cache.delete("views/collage-barcode-html-#{parent_id}")
      end
      relations.flatten.uniq.each do |rel_id|
        expire_page :controller => :collages, :action => :show, :id => rel_id
      end

      if record.changed.include?("public")
        #TODO: Move this into SweeperHelper, but right now doesn't call
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| expire_page :controller => type, :action => :show, :id => i.id }
        end
        Rails.cache.delete("user-barcode-#{record.user_id}")
      end
    rescue Exception => e
      Rails.logger.warn "Collage sweeper error: #{e.inspect}"
    end
  end

  def after_create(record)
    Rails.cache.delete("#{record.annotatable.class.to_s.downcase.gsub(/item/, '')}-barcode-#{record.annotatable_id}")
    Rails.cache.delete("views/#{record.annotatable.class.to_s.downcase.gsub(/item/, '')}-barcode-html-#{record.annotatable_id}")
  end

  def after_save(record)
    return true if record.changed.include?("created_at")

    # Note: For some reason, this is being triggered by base#embedded_pager, so this should skip it
    return true if params && params[:action] == "embedded_pager"

    return true if record.changed.include?("karma")

    collage_clear(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    collage_clear(record)
  end

  def after_collages_save_readable_state
    PlaylistItem.find(:all, :conditions => { :actual_object_type => 'Collage', :actual_object_id => params[:id] }, :select => :playlist_id).each do |pi|
      expire_page :controller => :playlists, :action => :show, :id => pi.playlist_id
      expire_page :controller => :playlists, :action => :export, :id => pi.playlist_id
    end
  end
end
