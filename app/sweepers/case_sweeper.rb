require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def clear_case(record)
    Rails.cache.delete_matched(%r{cases-search*})
    Rails.cache.delete_matched(%r{cases-embedded-search*})

    expire_page :controller => :cases, :action => :show, :id => record.id

    expire_fragment "case-#{record.id}-index"
    expire_fragment "case-#{record.id}-tags"
    expire_fragment "case-#{record.id}-detail"

    begin
      users = (record.owners + record.creators).uniq.collect { |u| u.id }
      users.each { |u| Rails.cache.delete("user-cases-#{u}") }
      if record.changed.include?("public")
        users.each { |u| Rails.cache.delete("user-barcode-#{u}") }
      end
    rescue Exception => e
    end
  end

  def after_save(record)
    clear_case(record)
  end

  def before_destroy(record)
    clear_case(record)
  end
end
