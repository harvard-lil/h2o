module PlaylistUtilities
  require 'net/http'
  require 'uri'

  include ActionView::Helpers::TextHelper

  def identify_object(url_string,uri)
    return_hash = Hash.new
    uri = URI.parse(url_string)
    metadata_hash = Hash.new
    object_type = ""

    metadata_hash = get_metadata_hash(url_string,uri)

    if metadata_hash["object-type"].present?
      object_type = metadata_hash["object-type"]
      
      created_date = ''
      begin
        created_date = Time.parse(metadata_hash['created-at']).to_s(:long)
      end

      case object_type
      when "QuestionInstance" then
        return_hash["type"] = "ItemQuestionInstance"
        return_hash['body'] = "<h3>#{h metadata_hash['title']}</h3>
<ul>
  <li>has #{h metadata_hash['child-object-count']} #{h metadata_hash['child-object-plural']}.</li>
  <li>was created #{h created_date}.</li>
</ul>" 
      when "RotisserieDiscussion" then
        return_hash["type"] = "ItemRotisserieDiscussion"
      when "Playlist" then
        return_hash["type"] = "ItemPlaylist"
      end
    elsif uri.host =~ /youtube.com$/
      return_hash["type"] = "ItemYoutube"
    else
      Net::HTTP.start(uri.host, uri.port) do |http|
        ### return_hash["result"] = http.head(url.request_uri)
        result = http.head(uri.request_uri)
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
          return_hash["body"] = truncate(http.get(uri.request_uri).body, :length => 1000)
        end
      end
    end

    if return_hash["type"].blank? then return_hash["type"] = "ItemDefault" end

    return return_hash

  end

  def get_metadata_hash(url,uri)
    result_hash = Hash.new

    result = nil
    document = nil
    begin
      #First check if the metadata method exists.
      agent = Net::HTTP.new(uri.host,uri.port)
      if(url.match(/^https/))
        agent.use_ssl = true
      end 
      req = Net::HTTP::Head.new(uri.request_uri + '/metadata')
      result = agent.start {|http|
        http.request(req)
      }

      if result.is_a?(Net::HTTPSuccess)
        get_data = Net::HTTP::Get.new(uri.request_uri + '/metadata')
        response = agent.start{|http|
          http.request(get_data)
        }
        document = Nokogiri::XML(response.body)
      end
    rescue Exception => e
      logger.warn("Failed to get metadata hash: " + e.inspect)
    end

    if document.present?
      document.xpath('//*').each do |node|
        result_hash[node.name] = node.text
      end
    end

    return result_hash
  end

  # Is this ItemQuestionInstance local? Meaning, does it live authoritatively in this h2o instance?
  def local?
    (actual_object) ? true : false
  end
end
