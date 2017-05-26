require 'sweeper_helper'
class TextBlockSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe TextBlock

  def clear_text_block(record)
    begin
      ActionController::Base.expire_page "/iframe/load/text_blocks/#{record.id}.html"
      ActionController::Base.expire_page "/iframe/show/text_blocks/#{record.id}.html"

      if record.saved_changes.keys.include?("public")
        #TODO: Move this into SweeperHelper, but right now doesn't call
        [:cases].each do |type|
          record.user.send(type).each { |i| ActionController::Base.expire_page "/#{type.to_s}/#{i.id}.html" }
          record.user.send(type).each { |i| ActionController::Base.expire_page "/iframe/load/#{type.to_s}/#{i.id}.html" }
          record.user.send(type).each { |i| ActionController::Base.expire_page "/iframe/show/#{type.to_s}/#{i.id}.html" }
        end
      end
    rescue Exception => e
      Rails.logger.warn "Textblock sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    return true if record.saved_changes.keys.include?("karma")

    clear_text_block(record)
    notify_private(record)
  end

  def before_destroy(record)
    clear_playlists(record.playlist_items)
    clear_text_block(record)
  end
end
