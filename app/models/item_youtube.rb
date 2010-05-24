class ItemYoutube < ActiveRecord::Base
  include AuthUtilities

  acts_as_authorization_object
  
  def preview
    require 'youtube_g'
    url = URI.parse(self.url)
    params_hash = CGI::parse(url.query)
    client = YouTubeG::Client.new

    params_hash["v"][0].present? ? video = client.video_by(params_hash["v"][0]) : video = client.video_by(self.url)

    return video.embed_html(300, 200)

  end

end
