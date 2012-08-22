require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def clear_case(record)
    Rails.cache.delete_matched(%r{cases-search*})
    Rails.cache.delete_matched(%r{cases-embedded-search*})

    expire_fragment "case-all-tags"
    expire_fragment "case-#{record.id}-index"
    expire_fragment "case-#{record.id}-tags"
    expire_fragment "case-#{record.id}-detail"

    # Note: For some reason, on destroy, b.user is nil. Works fine in other sweepers. Is mysterious.
    #users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['owner', 'creator'].include?(b.name); arr }.uniq

    users = Role.find(:all, :conditions => { :authorizable_type => 'Case', :authorizable_id => record.id, :name => ['owner', 'creator'] }).collect { |b| b.user }.uniq
    users.push(current_user.id) if current_user
    users.each { |u| Rails.cache.delete("user-cases-#{u}") }
  end

  def after_save(record)
    clear_case(record)
  end

  def before_destroy(record)
    clear_case(record)
  end
end
