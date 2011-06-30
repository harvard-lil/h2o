class ItemDefault < ActiveRecord::Base
  include AuthUtilities
 
  acts_as_authorization_object

  has_one :playlist_item, :as => :resource_item, :dependent => :destroy

  def preview(size_indicator = "S")
#    preview_content = <<-PREVIEW_CONTENT
#       <a href='#{self.url}' target='_blank' class='item_default_link'><img src='http://images.websnapr.com/?size=#{size_indicator}&key=#{WEBSNAPR_KEY}&url=#{self.url}' style='border: 1px solid #607887;' /></a>
#    PREVIEW_CONTENT

  end

  def bookmark_name
    self.name
  end
end
