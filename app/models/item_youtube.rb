class ItemYoutube < ActiveRecord::Base
  include AuthUtilities

  acts_as_authorization_object
  has_one :playlist_item, :as => :resource_item, :dependent => :destroy
  
  def preview
    require 'youtube_g'
    url = URI.parse(self.url)

    if url.query.present?
      params_hash = CGI::parse(url.query)
      client = YouTubeG::Client.new

      if params_hash.has_key?("v")
        video = client.video_by(params_hash["v"][0])
      else
        video = client.video_by(self.url)
      end

      return video.embed_html(300, 200)
    else
      return ""
    end

  end

end
