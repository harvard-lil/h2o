class ItemImage < ActiveRecord::Base
  include AuthUtilities

  acts_as_authorization_object

  def preview
    preview_content = <<-PREVIEW_CONTENT
       <a href='#{self.url}' target='_blank' class='item_default_link'><img src='#{self.url}' style='width: 200px; border: 1px solid #607887;' /></a>
    PREVIEW_CONTENT

    return preview_content

  end

end
