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

    # Note: For some reason, on destroy, b.user is nil. Works fine in other sweepers. Is mysterious.
    #users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['owner', 'creator'].include?(b.name); arr }.uniq

    users = Role.find(:all, :conditions => { :authorizable_type => 'TextBlock', :authorizable_id => record.id, :name => ['owner', 'creator'] }).collect { |b| b.user }.uniq
    users.each { |u| Rails.cache.delete("user-text_blocks-#{u}") }
  end

  def after_save(record)
    clear_text_block(record)
  end

  def before_destroy(record)
    clear_text_block(record)
  end
end
