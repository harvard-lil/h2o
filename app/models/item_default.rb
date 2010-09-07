class ItemDefault < ActiveRecord::Base
  include AuthUtilities
 
  acts_as_authorization_object

  has_one :playlist_item, :as => :resource_item

  def preview(size_indicator = "S")
    preview_content = <<-PREVIEW_CONTENT
       <a href='#{self.url}' target='_blank' class='item_default_link'><img src='http://images.websnapr.com/?size=#{size_indicator}&key=#{WEBSNAPR_KEY}&url=#{self.url}' style='border: 1px solid #607887;' /></a>
    PREVIEW_CONTENT
    return preview_content
  end
  
end
