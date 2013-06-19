require 'sweeper_helper'
class TextBlockSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe TextBlock

  def clear_text_block(record)
    Rails.cache.delete_matched(%r{text_blocks-search*})
    Rails.cache.delete_matched(%r{text_blocks-embedded-search*})

    expire_fragment "text_block-all-tags"
    expire_fragment "text_block-#{record.id}-index"
    expire_fragment "text_block-#{record.id}-tags"
    expire_fragment "text_block-#{record.id}-detail"

    begin
      users = (record.owners + record.creators).uniq.collect { |u| u.id }
      users.each { |u| Rails.cache.delete("user-text_blocks-#{u}") }
      if record.changed.include?("public")
        users.each { |u| Rails.cache.delete("user-barcode-#{u}") }
      end
    rescue Exception => e
    end
  end

  def after_save(record)
    clear_text_block(record)
  end

  def before_destroy(record)
    clear_text_block(record)
  end
end
