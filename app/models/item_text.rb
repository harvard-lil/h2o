class ItemText < ActiveRecord::Base
  include AuthUtilities
  include PlaylistUtilities

  acts_as_authorization_object
  has_one :playlist_item, :as => :resource_item, :dependent => :destroy
  belongs_to :actual_object, :polymorphic => true
  validates_presence_of :name

  def preview
    preview_content = <<-PREVIEW_CONTENT
       <div class="text_preview">#{self.description}</div>
    PREVIEW_CONTENT

    return preview_content

  end

end
