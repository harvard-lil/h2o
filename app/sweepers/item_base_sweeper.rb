require 'sweeper_helper'
class ItemBaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe ItemCollage, ItemCase, ItemPlaylist, ItemAnnotation, ItemQuestion, ItemQuestionInstance, ItemTextBlock, ItemDefault, ItemMedia

  def clear_playlists(playlist)
    if playlist.present?
      expire_page :controller => :playlists, :action => :show, :id => playlist.id
      expire_page :controller => :playlists, :action => :export, :id => playlist.id
      Rails.cache.delete("playlist-wordcount-#{playlist.id}")

      playlist.relation_ids.each do |p|
        expire_page :controller => :playlists, :action => :show, :id => p
        expire_page :controller => :playlists, :action => :export, :id => p
      end
    end
  end

  def actual_object_clear(actual_object)
    begin

      if actual_object.present?
        Rails.cache.delete("#{actual_object.class.to_s.downcase}-barcode-#{actual_object.id}")
        Rails.cache.delete("views/#{actual_object.class.to_s.downcase}-barcode-html-#{actual_object.id}")
        if [Playlist, Collage, Case].include?(actual_object.class)
          expire_page :controller => actual_object.class.to_s.tableize.to_sym, :action => :show, :id => actual_object.id
        end
      end
    rescue Exception => e
      Rails.logger.warn "Item base sweeper error: #{e.inspect}"
    end
  end

  def after_create(record)
    if params && params.has_key?(:container_id)
      playlist = Playlist.find(params[:container_id])
      clear_playlists(playlist)
    end
  end

  def after_update(record)
    if record && record.playlist_item
      clear_playlists(record.playlist_item.playlist)
    end

    actual_object_clear(record.actual_object)
  end

  def before_destroy(record)
    if record && record.playlist_item
      clear_playlists(record.playlist_item.playlist)
    end

    actual_object_clear(record.actual_object)
  end
end
