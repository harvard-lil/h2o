module PlaylistUtilities

  require 'net/http'
  require 'uri'

  include ActionView::Helpers::TextHelper

  def identify_object(url_string)
    return_hash = Hash.new
    url = URI.parse(url_string)

    if url.host =~ /youtube.com$/
      return_hash["type"] = "ItemYoutube"
    else
     Net::HTTP.start(url.host, url.port) do |http|
      ### return_hash["result"] = http.head(url.request_uri)
      result = http.head(url.request_uri)
      return_hash["content_type"] = result.content_type

         case return_hash["content_type"]
          when "text/html" then
            return_hash["type"] = "ItemDefault"
          when "image/jpeg" then
            return_hash["type"] = "ItemImage"
          when "image/png" then
            return_hash["type"] = "ItemImage"
          when "image/gif" then
            return_hash["type"] = "ItemImage"
          when "text/plain" then
            return_hash["type"] = "ItemText"
            return_hash["body"] = truncate(http.get(url.request_uri).body, :length => 1000)
        end
      end
    end

    return return_hash

  end

end
