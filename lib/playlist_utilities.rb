module PlaylistUtilities

  require 'net/http'
  require 'uri'

  include ActionView::Helpers::TextHelper

  def identify_object(url_string)
    return_hash = Hash.new
    url = URI.parse(url_string)
    metadata_hash = Hash.new
    object_type = ""

    metadata_hash = get_metadata_hash(url_string)

    if metadata_hash["object-type"].present?

      object_type = metadata_hash["object-type"]

      case object_type
      when "QuestionInstance" then
        return_hash["type"] = "ItemQuestionInstance"
      when "RotisserieDiscussion" then
        return_hash["type"] = "ItemRotisserieDiscussion"
      when "Playlist" then
        return_hash["type"] = "ItemPlaylist"
      end

    elsif url.host =~ /youtube.com$/
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

    if return_hash["type"].blank? then return_hash["type"] = "ItemDefault" end

    return return_hash

  end

  def get_metadata_hash(url)
    document = Nokogiri::XML(open(url + "/metadata"))
    result_hash = Hash.new

    if document.present?
      document.xpath('//*').each do |node|
        result_hash[node.name] = node.text
      end
    end

    return result_hash
  end

end
