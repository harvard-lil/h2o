require 'sweeper_helper'
class DefaultSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Default

  def default_clear(record)
    expire_page :controller => :defaults, :action => :show, :id => record.id

    Rails.cache.delete_matched(%r{defaults-search*})
    Rails.cache.delete_matched(%r{defaults-embedded-search*})

    expire_fragment "default-all-tags"
    expire_fragment "default-#{record.id}-index"

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if b.user && ['owner', 'creator'].include?(b.name); arr }.uniq
    users.push(current_user.id) if current_user
    users.each { |u| Rails.cache.delete("user-defaults-#{u}") }
  end

  def after_save(record)
    default_clear(record)
  end

  def before_destroy(record)
    default_clear(record)
  end
end
