require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def collage_clear(record)
    begin
      ActionController::Base.expire_page "/collages/#{record.id}.html"
      ActionController::Base.expire_page "/collages/#{record.id}/export.html"
 
      #expire pages of ancestors, descendants, and siblings meta
      relations = [record.ancestor_ids, record.descendant_ids]
      relations.push(record.sibling_ids.select { |i| i != record.id }) if record.parent.present?
      relations.flatten.uniq.each do |rel_id|
        ActionController::Base.expire_page "/collages/#{rel_id}.html"
      end

      if record.changed.include?("public")
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
        end
      end
    rescue Exception => e
      Rails.logger.warn "Collage sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    return true if record.changed.empty?

    return true if record.changed.include?("created_at")

    return true if record.changed.include?("readable_state")

    collage_clear(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    collage_clear(record)
  end

  def after_collages_save_readable_state
    ActionController::Base.expire_page "/collages/#{params[:id]}.html"
    ActionController::Base.expire_page "/collages/#{params[:id]}/export.html"

    PlaylistItem.where({ :actual_object_type => 'Collage', :actual_object_id => params[:id] }).select(:playlist_id).each do |pi|
      ActionController::Base.expire_page "/playlists/#{pi.playlist_id}.html"
      ActionController::Base.expire_page "/playlists/#{pi.playlist_id}/export.html"
    end
  end
end
