require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def after_save(record)
    Rails.cache.delete_matched(%r{cases-search*})
    expire_fragment "case-all-tags"
    expire_fragment "case-#{record.id}-index"
    expire_fragment "case-#{record.id}-tags"
    expire_fragment "case-#{record.id}-detail"

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['name', 'creator'].include?(b.name); arr }.uniq
    users.each do |u|
      Rails.cache.delete("user-cases-#{u}")
    end
  end

  def before_destroy(record)
    Rails.cache.delete_matched(%r{cases-search*})
    expire_fragment "case-all-tags"
    expire_fragment "case-#{record.id}-index"
    expire_fragment "case-#{record.id}-tags"
    expire_fragment "case-#{record.id}-detail"

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['name', 'creator'].include?(b.name); arr }.uniq
    users.each do |u|
      Rails.cache.delete("user-cases-#{u}")
    end
  end
end
