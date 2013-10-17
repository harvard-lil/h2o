require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def clear_case(record)
    begin
      Rails.cache.delete_matched(%r{cases-search*})
      Rails.cache.delete_matched(%r{cases-embedded-search*})
  
      expire_page :controller => :cases, :action => :show, :id => record.id
  
      expire_fragment "case-list-object-#{record.id}"

      if record.changed.include?("public")
        Rails.cache.delete("user-barcode-#{record.user_id}")
      end
    rescue Exception => e
      Rails.logger.warn "Case sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    # Note: For some reason, this is being triggered by base#embedded_pager, so this should skip it
    return if params && params[:action] == "embedded_pager"

    clear_case(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    clear_case(record)
  end
end
