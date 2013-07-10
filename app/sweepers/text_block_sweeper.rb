require 'sweeper_helper'
class TextBlockSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe TextBlock

  def clear_text_block(record)
    begin
      Rails.cache.delete_matched(%r{text_blocks-search*})
      Rails.cache.delete_matched(%r{text_blocks-embedded-search*})
  
      expire_fragment "text_block-all-tags"
      expire_fragment "text_block-#{record.id}-index"
      expire_fragment "text_block-#{record.id}-tags"
      expire_fragment "text_block-#{record.id}-detail"

      users = (record.owners + record.creators).uniq
      if record.changed.include?("public")
        users.each do |u|
          #TODO: Move this into SweeperHelper, but right now doesn't call
          [:playlists, :collages, :cases].each do |type|
            u.send(type).each { |i| expire_page :controller => type, :action => :show, :id => i.id }
          end
          Rails.cache.delete("user-barcode-#{u.id}")
        end
      end
      users.each { |u| Rails.cache.delete("user-text_blocks-#{u.id}") }
    rescue Exception => e
      Rails.logger.warn "Textblock sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    clear_text_block(record)
  end

  def before_destroy(record)
    clear_text_block(record)
  end
end
