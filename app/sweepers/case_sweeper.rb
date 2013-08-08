require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def clear_case(record)
    begin
      Rails.cache.delete_matched(%r{cases-search*})
      Rails.cache.delete_matched(%r{cases-embedded-search*})
  
      expire_page :controller => :cases, :action => :show, :id => record.id
  
      expire_fragment "case-list-object-#{record.id}"

      users = record.owners
      if record.changed.include?("public")
        users.each do |u|
          Rails.cache.delete("user-barcode-#{u.id}")
        end
      end
      users.each { |u| Rails.cache.delete("user-cases-#{u.id}") }
    rescue Exception => e
      Rails.logger.warn "Case sweeper error: #{e.inspect}"
    end
  end

  def after_save(record)
    clear_case(record)
  end

  def before_destroy(record)
    clear_case(record)
  end
end
