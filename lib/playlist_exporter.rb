require 'tempfile'
require 'uri'

class PlaylistExporter

  class << self

    def export_as(request_url, params)
      export_format = params[:export_format]

      if export_format == 'doc'
        return export_as_doc(request_url, params)
      elsif export_format == 'pdf'
        pdf_file = export_as_pdf(request_url, params)
        return pdf_file
      elsif export_format == 'epub'
        pdf_file = export_as_pdf(request_url, params)
        return export_as_epub(pdf_file, params)
      else
        raise "Unsupported export_format #{export_format}"
      end
    end

    def export_as_doc(request_url, params)
      #fetch HTML with phantomjs (and cookies) into a temp file in /tmp/playlist_exports/
      html_file = fetch_playlist_html(request_url, params)
      return convert_to_mime_file(html_file)
    end

    def json_options_file(params)
      #TODO: use Tempfile.new when done debugging
      #file = Tempfile.new(['phantomjs-args-', '.json'])
      file = File.new('tmp/phantomjs/last-phantomjs-options.json', 'w')
      file.write forwarded_cookies_hash(params).to_json
      file.close
      file.path  #.tap {|x| Rails.logger.debug "JSON: #{x}" }
    end

    def fetch_playlist_html(request_url, params)
      #TODO: clean up code/names here
      target_url = get_target_url(request_url, params[:id])

      base_dir = Rails.root.join('tmp/phantomjs')
      FileUtils.mkdir(base_dir) unless File.exist?(base_dir)
      out_file = Dir::Tmpname.create(params[:id], base_dir) {|path| path}

      options_file = json_options_file(params)
      command = [
                 'bin/phantomjs',
                 'bin/htmlize.js',
                 target_url,
                 out_file,
                 options_file,
                ]
      Rails.logger.debug command.join(' ')

      exit_code = nil
      command_output = ''
      Open3.popen2e(*command) do |i, out_err, wait_thread|
        out_err.each {|line| command_output += "PHANTOMJS: #{line}"}
        exit_code = wait_thread.value.exitstatus
      end

      #File.write('/tmp/last-phantomjs-call', command.join(' '))  #TODO: remove
      Rails.logger.debug command.join(' ')
      Rails.logger.debug command_output

      if exit_code == 0
        out_file
      else
        Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_output}"
      end

      out_file.tap {|x| Rails.logger.debug "Created #{x}" }
    end

    def convert_to_mime_file(input_file)
      boundary = "----=_NextPart_ZROIIZO.ZCZYUACXV.ZARTUI"
      lines = []
      lines << "MIME-Version: 1.0"
      lines << "Content-Type: multipart/related; boundary=\"#{boundary}\""
      lines << ""
      lines << '--' + boundary
      lines << "Content-Location: file:///C:/boop.htm"
      lines << "Content-Transfer-Encoding: base64"
      lines << "Content-Type: text/html; charset=\"utf-8\""
      lines << ""
      lines << Base64.encode64(File.read(input_file))

      tempfile = '/tmp/last-encoded-file.doc'  #TODO: Use a real tempfile filename for this
      #Note: only the last boundary seems to need the final trailing "--" ?
      delim = "\n"
      File.write(tempfile, lines.join(delim) + delim + "--" + boundary + "--")
      return tempfile
    end

    def export_as_epub(pdf_file, params)
      #TODO: DRY this up with other export_as_* methods
      out_file = pdf_file.gsub(/\.pdf$/, '.epub')
      command = [
                 Rails.root.to_s + '/tmp/calibre/ebook-convert',
                 pdf_file,
                 out_file,
      ]
      exit_code = nil
      command_output = ''
      Open3.popen2e(*command) do |i, out_err, wait_thread|
        out_err.each {|line| command_output += "CALIBREEPUB: #{line}"}
        exit_code = wait_thread.value.exitstatus
      end

      File.write('/tmp/last-calibre-call', command.join(' '))  #TODO: remove
      Rails.logger.debug command.join(' ')
      Rails.logger.debug command_output

      if exit_code == 0
        out_file
      else
        Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_output}"
      end
    end

    def export_as_pdf(request_url, params)
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

      File.write('/tmp/last-wkhtmltopdf-call', command.join(' '))  #TODO: remove
      Rails.logger.debug command.join(' ')
      Rails.logger.debug command_output

      if exit_code == 0
        command.last
      else
        Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_output}"
        false
      end
    end

    def convert_h_tags(doc)
      # Accepts text or Nokogiri document
      if !doc.respond_to?(:xpath)
        doc.gsub!(/\r\n/, '')
        return '' if doc == '' || doc == '<br>'

        if doc.length < 40
          Rails.logger.debug "BEEP: '#{doc}'"
        end

        doc = Nokogiri::HTML.parse(doc)
      end

      doc.xpath("//h1 | //h2 | //h3 | //h4 | //h5 | //h6").each do |node|
        node['class'] = node['class'].to_s + " new-h#{ node.name.match(/h(\d)/)[1] }"
        node.name = 'div'
      end

      doc
    end

    def forwarded_cookies(params)
      if params[:export_format] == 'pdf'
        cookies = forwarded_cookies_hash(params).except(*[
                                                         'print_margin_top',
                                                         'print_margin_right',
                                                         'print_margin_bottom',
                                                         'print_margin_left',
                                                        ])
      else
        cookies = forwarded_cookies_hash(params)
      end
      Rails.logger.debug "Using cookies: #{cookies}"
      cookies.map {|k,v|
        "--cookie #{k} #{encode_cookie_value(v)}" if v.present?
      }.join(' ')
    end

    def forwarded_cookies_hash(params)
      # This performs the reverse of export.js:init_user_settings() by mapping
      # form field names to cookie names while also translating values.
      # Ideally we would just consolidate the form field names to match cookie names
      # as well as no longer using multiple forms of true and false.

      # No translation value here means we just pass the form field value straight through
      # Note: We don't send marginsize because margins are set via the wkhtmltopdf command line
      #TODO: Translate all values rather than just the ones that export.js looks for.
      field_to_cookie = {
        'printtitle' => {'cookie_name' => 'print_titles', 'cookval' => 'false', 'formval' => 'no', },
        'printdetails' => {'cookie_name' => 'print_dates_details', 'cookval' => 'false', 'formval' => 'no', },
        'printparagraphnumbers' => {'cookie_name' => 'print_paragraph_numbers', 'cookval' => 'false', 'formval' => 'no', },
        'printannotations' => {'cookie_name' => 'print_annotations', 'cookval' => 'true', 'formval' => 'yes', },
        'hiddentext' => {'cookie_name' => 'hidden_text_display', 'cookval' => 'true', 'formval' => 'show', },
        'printhighlights' => {'cookie_name' => 'print_highlights'},
        'fontface' => {'cookie_name' => 'print_font_face'},
        'fontsize' => {'cookie_name' => 'print_font_size'},
        'margin-top' => {'cookie_name' => 'print_margin_top'},
        'margin-right' => {'cookie_name' => 'print_margin_right'},
        'margin-bottom' => {'cookie_name' => 'print_margin_bottom'},
        'margin-left' => {'cookie_name' => 'print_margin_left'},
      }

      cookies = {'print_export' => 'true'}
      field_to_cookie.each do |field, v|
        if params[field].present?
          #Rails.logger.debug "FtCookie got: #{field} -> '#{params[field]}'"
          if params[field] == v['formval']
            #translate it
            cookies[v['cookie_name']] = v['cookval']
          elsif v['cookval'].nil?
            cookies[v['cookie_name']] = params[field]
          end
        end
      end
      cookies  #.tap {|x| Rails.logger.debug "FTC created:\n#{x}"}
    end

    def generate_toc_levels_css(depth)
      # TODO: Could we use this instead?
      #    <xsl:template match="outline:item[count(ancestor::outline:item)<=2]">
      # <li class="book-toc-item level_{count(ancestor::outline:item)}">
      depth = depth.to_i

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

    def generate_toc_general_css(params)
      #TODO: we may need to map the value we get using fonts.js:h2o_fonts
      #Or map it pre-emptively on the client side
      #  #{params['fontface']}
      " .toc {
          font-family: leitura-news;
          font-size: #{params['fontsize']};
        }
      "
    end

    def render_toc(params)
      vars = {
        :title => params['playlist_name'],
        :general_css => generate_toc_general_css(params),
        :toc_levels_css => generate_toc_levels_css(params['toc_levels']),
      }

      ApplicationController.new.render_to_string(
                                                 "playlists/toc.xsl",
                                                 :layout => false,
                                                 :locals => vars,
                                                 )  #.tap {|x| Rails.logger.debug x}
    end

    def generate_toc_options(params)
      options = ["--no-outline"]
      if params['toc_levels'].present?
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

    def generate_page_options(params)
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

      global_options = %w[margin-top margin-right margin-bottom margin-left].map {|name|
        "--#{name} #{params[name]}"
      }.join(' ')
      toc_options = generate_toc_options(params)
      page_options = generate_page_options(params)
      cookie_string = forwarded_cookies(params)
      output_file_path = output_filename(object_id)
      prep_output_file_path(output_file_path)
      target_url = get_target_url(request_url, object_id)

      Rails.logger.debug output_file_path
      #Rails.logger.debug output_file_url
      [
       binary,
       global_options,
       toc_options,
       'page',
       target_url,
       page_options,
       cookie_string,
       output_file_path,  #This always has to be last in this array
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
