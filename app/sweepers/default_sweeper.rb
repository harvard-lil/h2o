require 'sweeper_helper'
class DefaultSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Default

  def default_clear(record)
    Rails.cache.delete_matched(%r{defaults-search*})
    Rails.cache.delete_matched(%r{defaults-embedded-search*})

    record.ancestor_ids.each do |parent_id|
      Rails.cache.delete("default-barcode-#{parent_id}")
      Rails.cache.delete("views/default-barcode-html-#{parent_id}")
    end

    ActionController::Base.new.expire_fragment "default-#{record.id}-index"
  end

  def after_save(record)
    # FIXME
    # Note: For some reason, this is being triggered by base#embedded_pager, so this should skip it
    # return if params && params[:action] == "embedded_pager"

    default_clear(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    default_clear(record)
  end
end
