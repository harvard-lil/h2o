require 'sweeper_helper'
class CollageSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Collage

  def after_save(record)
    #Rails.cache.delete(%r{collages-search*})
    #Rails.cache.delete(%r/collages-search*/)
    # TODO: Figure out a better way to do this
    tag_list = [Collage.tag_list.collect { |t| t.name }, ''].flatten
    1.upto(Collage.count/25) do |page|
      tag_list.each do |tag|
        ['', 'author', 'created_at', 'display_name'].each do |sort|
        RAILS_DEFAULT_LOGGER.warn "steph: #{page}-#{tag}-#{sort}"
          Rails.cache.delete("collages-search-#{page}-#{tag}-#{sort}")
        end
      end
    end

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

    users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['name', 'creator'].include?(b.name); arr }.uniq
    users.each do |u|
      Rails.cache.delete("user-collages-#{u}")
    end
  end

  def before_destroy(record)
    #Rails.cache.delete(%r{collages-search*})
    #Rails.cache.delete(%r/collages-search*/)
    # TODO: Figure out a better way to do this
    tag_list = [Collage.tag_list.collect { |t| t.name }, ''].flatten
    1.upto(Collage.count/25) do |page|
      tag_list.each do |tag|
        ['', 'author', 'created_at', 'display_name'].each do |sort|
        RAILS_DEFAULT_LOGGER.warn "steph: #{page}-#{tag}-#{sort}"
          Rails.cache.delete("collages-search-#{page}-#{tag}-#{sort}")
        end
      end
    end

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

      users = record.accepted_roles.inject([]) { |arr, b| arr.push(b.user.id) if ['name', 'creator'].include?(b.name); arr }.uniq
    users.each do |u|
      Rails.cache.delete("user-collages-#{u}")
    end
  end
end
