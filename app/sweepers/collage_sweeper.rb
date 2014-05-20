require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def collage_clear(record)
    begin
      ActionController::Base.expire_page "/collages/#{record.id}.html"
      ActionController::Base.expire_page "/collages/#{record.id}/export.html"
      return if params && params[:action] == 'save_readable_state'
 
      Rails.cache.delete_matched(%r{collages-search*})
      Rails.cache.delete_matched(%r{collages-embedded-search*})

      ActionController::Base.new.expire_fragment "collage-list-object-#{record.id}"

      #expire fragments of my ancestors, descendants, and siblings meta
      relations = [record.ancestor_ids, record.descendant_ids]
      relations.push(record.sibling_ids.select { |i| i != record.id }) if record.parent.present?

      record.ancestor_ids.each do |parent_id|
        Rails.cache.delete("collage-barcode-#{parent_id}")
        Rails.cache.delete("views/collage-barcode-html-#{parent_id}")
      end
      relations.flatten.uniq.each do |rel_id|
        ActionController::Base.expire_page "/collages/#{rel_id}.html"
      end

      if record.changed.include?("public")
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
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
    return true if record.changed.empty?

    return true if record.changed.include?("created_at")

    return true if record.changed.include?("karma")

    collage_clear(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    collage_clear(record)
  end

  def after_collages_save_readable_state
    PlaylistItem.where({ :actual_object_type => 'Collage', :actual_object_id => params[:id] }).select(:playlist_id).each do |pi|
      ActionController::Base.expire_page "/playlists/#{pi.playlist_id}.html"
      ActionController::Base.expire_page "/playlists/#{pi.playlist_id}/export.html"
    end
  end
end
