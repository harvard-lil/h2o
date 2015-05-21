require 'tempfile'
require 'uri'

class PlaylistExporter

  class << self

    def export_as(request_url, params)
      #request_url will actually be the full request URI that is posting TO this page. We need
      # pieces of that that to construct the URL we are going to pass to wkhtmltopdf
      # target_url = "http://sskardal03.murk.law.harvard.edu:8000/playlists/19763/export"
      command = generate_command(request_url, params)

      exit_code = nil
      command_output = ''
      Open3.popen2e(*command) do |i, out_err, wait_thread|
        out_err.each {|line| command_output += "WKHTMLTOPDF: #{line}"}
        exit_code = wait_thread.value.exitstatus
      end

      Rails.logger.debug command.join(' ')
      Rails.logger.debug command_output
      #ASYNC
      #if it failed, email "sorry" message that we BCC to an admin
      #if it succeeded, email "here is your link" message
      if exit_code == 0
        command.last
      else
        Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_output}"
        false
      end
    end

    def convert_h_tags(doc)
      # Accepts text & html as well as Nokogiri documents
      doc = Nokogiri::HTML.parse(doc) unless doc.respond_to?(:xpath)

      doc.xpath("//h1 | //h2 | //h3 | //h4 | //h5 | //h6").each do |node|
        node['class'] = node['class'].to_s + " new-h#{ node.name.match(/h(\d)/)[1] }"
        node.name = 'div'
      end
      doc
    end

    def forwarded_cookies(params)
      # This performs the reverse of export.js:init_user_settings() by mapping
      # form field names to cookie names while also translating values.
      # Ideally we would just consolidate the form field names to match cookie names
      # and stop using multiple forms of true and false.

      # No translation value here means we just pass the form field value straight through
      field_to_cookie = {
        'printtitle' => {'cookie_name' => 'print_titles', 'cookval' => 'false', 'formval' => 'no', },
        'printdetails' => {'cookie_name' => 'print_dates_details', 'cookval' => 'false', 'formval' => 'no', },
        'printparagraphnumbers' => {'cookie_name' => 'print_paragraph_numbers', 'cookval' => 'false', 'formval' => 'no', },
        'printannotations' => {'cookie_name' => 'print_annotations', 'cookval' => 'true', 'formval' => 'yes', },
        'hiddentext' => {'cookie_name' => 'hidden_text_display', 'cookval' => 'true', 'formval' => 'show', },
        'printhighlights' => {'cookie_name' => 'print_highlights'},
        'fontface' => {'cookie_name' => 'print_font_face'},
        'fontsize'=> {'cookie_name' => 'print_font_size'},
      }

      cookies = {'force_boop' => 'true'}
      field_to_cookie.each do |field, v|
        if params[field].present?
          if params[field] == v['formval']
            cookies[v['cookie_name']] = v['cookval']
          elsif v['cookval'].nil?
            cookies[v['cookie_name']] = params[field]
          end
        end
      end

      cookies.map {|k,v| "--cookie #{k} #{encode_cookie_value(v)}" if v.present?}.join(' ')
    end

    def generate_toc_levels_css(depth)
      # TODO: Could we use this,w hich I just found?
      #    <xsl:template match="outline:item[count(ancestor::outline:item)&lt;=2]">
      # <li class="book-toc-item level_{count(ancestor::outline:item)}">
      depth = depth.to_i
      return "" if depth == 0
      
      # This starting css defines basic indentation for all levels that do get displayed
      css = [
             "ul {padding-left: 0em;}",
             "ul ul {padding-left: 1em;}",
            ]
      # Add CSS to hide any levels that are > depth
      (1..6).each do |i|
        if i > depth
          css << ("ul " * i) + "{display: none;}"
        end
      end
      css.join("\n")
    end

    def render_toc(params)
      vars = {
        :title => "rendered-title",  #TODO: use @playlist.name
        :general_css => ".general_css {}",  #TODO: implement
        :toc_levels_css => generate_toc_levels_css(params['toc_levels']),
      }

      ApplicationController.new.render_to_string(
                                                 "playlists/toc.xsl",
                                                 :layout => false,
                                                 :locals => vars,
                                                 ).tap {|x| Rails.logger.debug x}
    end

    def generate_toc_options(params)
      # No PDF-specific "outline" (displayed in the left sidebar in Adobe PDF Reader)
      options = ["--no-outline"]
      if params['toc_levels']
        options << "toc --xsl-style-sheet " + toc_file(params)
      end
      options
    end

    def toc_file(params)
      #NOTE: There may be a risk tempfile will unlink this file before it gets used,
      #so we probably need a regular IO file that we unlink or clear some other way.
      file = Tempfile.new(['export_toc', '.xsl'])
      file.write render_toc(params)
      file.close
      file.path
    end

    def generate_options(params)
      # The order of options is important with respect to options that are passed to
      # the "toc" (aka "TOC options" in the wkhtmltopdf docs) versus global options.
      options = []

      #TODO: See if we can get rid of --javascript-delay. If you remove it and all the
      # javascript special effects still run, then you didn't need it any more.
      options << "--no-stop-slow-scripts --javascript-delay 1000 --debug-javascript"
      options << "--print-media-type"

      # The below is only needed if you do not have a DNS or /etc/hosts entry for
      # this dev server. However, it will probably break the typekit JS call
      #hostname = URI(request_url).host  #"sskardal03.murk.law.harvard.edu"
      #options << "--custom-header-propagation --custom-header host #{hostname}"
      options
    end

    def generate_command(request_url, params)
      object_id = params['id']
      binary = 'wkhtmltopdf'

      toc_options = generate_toc_options(params)

      options = generate_options(params)
      cookie_string = forwarded_cookies(params)
      output_file_path = output_filename(object_id)
      prep_output_file_path(output_file_path)
      #output_file_url = output_filename_relative_path(output_file_path)
      target_url = get_target_url(request_url, object_id)
      
      Rails.logger.debug output_file_path
      #Rails.logger.debug output_file_url
      [
       binary,
       toc_options,
       'page',
       target_url,
       options,
       cookie_string,
       output_file_path,
      ].flatten.join(' ').split
    end

    def prep_output_file_path(output_file_path)
      FileUtils.mkdir_p(File.dirname(output_file_path))
    end
      
    def get_target_url(request_url, id)
      uri = URI(request_url)
      Rails.application.routes.url_helpers.export_playlist_url(
                          :id => id,
                          :host => uri.host,  #murk: '128.103.64.117',
                          :port => uri.port
                          )
    end

    def output_filename_relative_path(full_path)
      begin
        full_path.match(%r{(/public/playlists/.+)$})[0]
      rescue => e
        raise "Failed to find output_filename_relative_path in #{full_path}"
      end
    end

    def output_filename(object_id)
      object_id.gsub!(/\D/, '')
      #TODO: adjust this path to match the current export URL style
      filename_hash = SecureRandom.hex(4)
      Rails.root.join(
                      'public',
                      'playlists',
                      object_id.to_s,
                      "playlist-#{object_id}-#{filename_hash}.pdf"
                      ).to_s
    end

    def encode_cookie_value(val)
       ERB::Util.url_encode(val)
    end

  end
end
