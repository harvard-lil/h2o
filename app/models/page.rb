class Page < ApplicationRecord
  validates_presence_of :page_title, :slug

  after_save :clear_cached_page

  def clear_cached_page
    page = Page.where(id: id).first
    ActionController::Base.expire_page "/p/#{page.slug}.html"

    # TODO: Page management if link settings change
  end
end
