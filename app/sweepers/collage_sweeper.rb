require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def after_save(record)
    Rails.cache.delete_matched(%r{collages-search*})

    expire_fragment "collage-all-tags"
    expire_fragment "collage-#{record.id}-index"
    expire_fragment "collage-#{record.id}-tags"
    expire_fragment "collage-#{record.id}-annotations"
    expire_fragment "case-#{record.annotatable_id}-index"

    #expire fragments of my ancestors, descendants, and siblings meta
    relations = [record.path_ids, record.descendant_ids]
    relations.push(record.sibling_ids) if !record.ancestry.nil?
    relations.flatten.uniq.each do |rel_id|
      expire_fragment "collage-#{rel_id}-meta"
    end

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['owner', 'creator'].include?(b.name); arr }.uniq.push(current_user.id)
    users.each { |u| Rails.cache.delete("user-collages-#{u}") }
  end

  def before_destroy(record)
    Rails.cache.delete_matched(%r{collages-search*})

    expire_fragment "collage-all-tags"
    expire_fragment "collage-#{record.id}-index"
    expire_fragment "collage-#{record.id}-tags"
    expire_fragment "collage-#{record.id}-annotations"
    expire_fragment "case-#{record.annotatable_id}-index"

    #expire fragments of my ancestors, descendants, and siblings meta
    relations = [record.path_ids, record.descendant_ids]
    relations.push(record.sibling_ids) if !record.ancestry.nil?
    relations.flatten.uniq.each do |rel_id|
      expire_fragment "collage-#{rel_id}-meta"
    end

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['owner', 'creator'].include?(b.name); arr }.uniq.push(current_user.id)
    users.each { |u| Rails.cache.delete("user-collages-#{u}") }
  end
end
