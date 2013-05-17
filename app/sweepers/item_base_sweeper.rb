require 'sweeper_helper'
class ItemBaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe ItemCollage, ItemCase, ItemPlaylist, ItemAnnotation, ItemQuestion, ItemQuestionInstance, ItemTextBlock, ItemDefault, ItemMedia

  def clear_playlists(playlist)
    expire_page :controller => :playlists, :action => :show, :id => playlist.id
    expire_page :controller => :playlists, :action => :export, :id => playlist.id

    playlist.relation_ids.each do |p|
      expire_page :controller => :playlists, :action => :show, :id => p
      expire_page :controller => :playlists, :action => :export, :id => p
    end
  end

  def after_create(record)
    if params && params.has_key?(:container_id)
      playlist = Playlist.find(params[:container_id])
      clear_playlists(playlist)
    end
    if record && [ItemPlaylist, ItemCollage, ItemMedia, ItemTextBlock, ItemCase].include?(record.class) && record.actual_object
      Rails.cache.delete("#{record.class.to_s.downcase.gsub(/item/, '')}-barcode-#{record.actual_object.id}")
    end
  end

  def after_update(record)
    if record && record.playlist_item
      clear_playlists(record.playlist_item.playlist)
    end
    if record && [ItemPlaylist, ItemCollage, ItemMedia, ItemTextBlock, ItemCase].include?(record.class) && record.actual_object
      Rails.cache.delete("#{record.class.to_s.downcase.gsub(/item/, '')}-barcode-#{record.actual_object.id}")
    end
  end

  def before_destroy(record)
    if record && record.playlist_item
      clear_playlists(record.playlist_item.playlist)
    end
    if record && [ItemPlaylist, ItemCollage].include?(record.class) && record.actual_object
      Rails.cache.delete("#{record.class.to_s.downcase.gsub(/item/, '')}-barcode-#{record.actual_object.id}")
    end
  end
end
