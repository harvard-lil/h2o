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

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['owner', 'creator'].include?(b.name); arr }.uniq.push(current_user.id)
    users.each { |u| Rails.cache.delete("user-text_blocks-#{u}") }
  end

  def after_save(record)
    clear_text_block(record)
  end

  def before_destroy(record)
    clear_text_block(record)
  end
end
