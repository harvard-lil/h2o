require 'sweeper_helper'
class TextBlockSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe TextBlock

  def clear_text_block(record)
    begin
      Rails.cache.delete_matched(%r{text_blocks-search*})
      Rails.cache.delete_matched(%r{text_blocks-embedded-search*})
  
      expire_fragment "text_block-#{record.id}-tags"
      expire_fragment "text_block-#{record.id}-detail"
      expire_fragment "textblock-list-object-#{record.id}"

      if record.changed.include?("public")
        #TODO: Move this into SweeperHelper, but right now doesn't call
        [:playlists, :collages, :cases].each do |type|
          record.user.send(type).each { |i| expire_page :controller => type, :action => :show, :id => i.id }
        end
        Rails.cache.delete("user-barcode-#{record.user_id}")
      end
    rescue Exception => e
      Rails.logger.warn "Textblock sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    # Note: For some reason, this is being triggered by base#embedded_pager, so this should skip it
    return if params && params[:action] == "embedded_pager"

    clear_text_block(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    clear_text_block(record)
    #notify_destroy(record)
  end
end
