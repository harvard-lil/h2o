class ItemText < ActiveRecord::Base
  include AuthUtilities

  acts_as_authorization_object

  def preview
    preview_content = <<-PREVIEW_CONTENT
       <div class="text_preview">#{self.description}</div>
    PREVIEW_CONTENT

    return preview_content

  end

end
