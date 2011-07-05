require 'sweeper_helper'
class CaseSweeper < ActionController::Caching::Sweeper
  include SweeperHelper
  observe Case

  def after_save(record)
	expire_fragment "case-all-tags"
	expire_fragment "case-#{record.id}-index"
	expire_fragment "case-#{record.id}-tags"
  end

  def before_destroy(record)
	expire_fragment "case-all-tags"
	expire_fragment "case-#{record.id}-index"
	expire_fragment "case-#{record.id}-tags"
  end
end
