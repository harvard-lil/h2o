# == Schema Information
#
# Table name: pages
#
#  id                   :integer          not null, primary key
#  page_title           :string(255)      not null
#  slug                 :string(255)      not null
#  content              :text
#  created_at           :datetime
#  updated_at           :datetime
#  footer_link          :boolean          default(FALSE), not null
#  footer_link_text     :string(255)
#  footer_sort          :integer          default(1000), not null
#  is_user_guide        :boolean          default(FALSE), not null
#  user_guide_sort      :integer          default(1000), not null
#  user_guide_link_text :string(255)
#

class Page < ActiveRecord::Base
  validates_presence_of :page_title, :slug

  after_save :clear_cached_page

  def clear_cached_page
    page = Page.where(id: id).first
    ActionController::Base.expire_page "/p/#{page.slug}.html"

    # TODO: Page management if link settings change
  end
end
