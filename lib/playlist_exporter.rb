require 'tempfile'
require 'uri'

# TODO: Now that it's stable, this would benefit from bundle of refacting into
#   the intended ExportService class.
class PlaylistExporter

  class ExportException < StandardError; end

  # No translation value here means we just pass the form field value straight through
  # Some cookies are just here to make them available to PhantomJS
  # TODO: translate all values, rather than only translating the one value that signals
  # export.js to do the thing that is "not the default."
  #If you want to forwad a cookie from the print header all the way through to one
  #of the exporters, it needs to be listed here.
  FORM_COOKIE_MAP = {
    '_h2o_session' => {'cookie_name' => '_h2o_session'},
    'printtitle' => {'cookie_name' => 'print_titles', 'cookval' => 'false', 'formval' => 'no', },
    'printparagraphnumbers' => {'cookie_name' => 'print_paragraph_numbers', 'cookval' => 'false', 'formval' => 'no', },
    'printannotations' => {'cookie_name' => 'print_annotations', 'cookval' => 'true', 'formval' => 'yes', },
    'printlinks' => {'cookie_name' => 'print_links' },
    'hiddentext' => {'cookie_name' => 'hidden_text_display', 'cookval' => 'true', 'formval' => 'show', },
    'printhighlights' => {'cookie_name' => 'print_highlights'},
    'fontface' => {'cookie_name' => 'print_font_face'},
    'fontsize' => {'cookie_name' => 'print_font_size'},
    'fontface_mapped' => {'cookie_name' => 'print_font_face_mapped'},
    'fontsize_mapped' => {'cookie_name' => 'print_font_size_mapped'},
    'margin-top' => {'cookie_name' => 'print_margin_top'},
    'margin-right' => {'cookie_name' => 'print_margin_right'},
    'margin-bottom' => {'cookie_name' => 'print_margin_bottom'},
    'margin-left' => {'cookie_name' => 'print_margin_left'},
    'toc_levels' => {'cookie_name' => 'toc_levels'},
  }

  class << self

    def export_as(opts)
      request_url = opts[:request_url]
      params = opts[:params]
      session_cookie = opts[:session_cookie]
      email_address = opts[:email_to]

      #required for owners to export their own private content
      params.merge!(:_h2o_session => session_cookie)

      export_format = params[:export_format]
      exported_file = nil
      begin
        if export_format == 'doc'
          exported_file = export_as_doc(request_url, params)
        elsif export_format == 'pdf'
          exported_file = export_as_pdf(request_url, params)
        else
          raise "Unsupported export_format '#{export_format}'"
        end
      rescue StandardError => e
        Rails.logger.debug "~~export_as exception: #{e}"
        #ExceptionNotifier.notify_exception(e)
        raise e
      end

      export_result = ExportService::ExportResult.new(
        content_path: exported_file,
        item_name: params['item_name'],
        format: params['export_format'],
        )

      if email_address
        email_download_link(export_result.content_path, email_address)
      end

      export_result
    end

    def email_download_link(content_path, email_address)  #_base
      Notifier.export_download_link(content_path, email_address).deliver
    end

    def export_as_doc(request_url, params)  #_doc
      convert_to_mime_file(fetch_playlist_html(request_url, params))
    end

    def json_options_file(params)  #_doc
      #TODO: use Tempfile.new when done debugging
      #file = Tempfile.new(['phantomjs-args-', '.json'])
      file = File.new('tmp/phantomjs/last-phantomjs-options.json', 'w')
      file.write forwarded_cookies_hash(params).to_json
      file.close
      file.path  #.tap {|x| Rails.logger.debug "JSON: #{x}" }
    end

    def output_file_path(params)  #_base
      base_dir = Rails.root.join('public/exports')
      FileUtils.mkdir(base_dir) unless File.exist?(base_dir)

      out_dir = Dir::Tmpname.create(params[:id], base_dir) {|path| path}
      FileUtils.mkdir(out_dir) unless File.exist?(out_dir)

      filename = (params[:item_name].to_s || "download").parameterize.underscore
      out_dir + '/' + filename + '.' + params[:export_format]
    end

    def fetch_playlist_html(request_url, params)  #_doc
      target_url = get_target_url(request_url)
      options_file = json_options_file(params)
      out_file = output_file_path(params)
      out_file.sub!(/#{File.extname(out_file)}$/, '.html')

      command = [
                 'bin/phantomjs',
                 #'--debug=true',
                 'bin/htmlize.js',
                 target_url,
                 out_file,
                 options_file,
                ]
      Rails.logger.debug command.join(' ')

      exit_code = nil
      command_output = []
      Open3.popen2e(*command) do |_, out_err, wait_thread|
        out_err.each {|line|
          Rails.logger.debug "PHANTOMJS: #{line.rstrip}"
          command_output << line
        }
        exit_code = wait_thread.value.exitstatus
      end
      command_text = command_output.join("\n")

      if exit_code == 0
        out_file.tap {|x| Rails.logger.debug "Created #{x}" }
      else
        Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_text}"
        raise ExportException, command_text
      end
    end

    def convert_to_mime_file(input_file)  #_doc
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

      output_file = input_file.sub(/#{File.extname(input_file)}$/, '.doc')

      #TODO: We could delete input_file after we write output_file
      #Note: only the last boundary seems to need the final trailing "--". That
      # could just be Word being, well, Word. *sigh*
      delim = "\n"
      File.write(output_file, lines.join(delim) + delim + "--" + boundary + "--")
      output_file
    end

    def export_as_pdf(request_url, params)  #_pdf
      command = pdf_command(request_url, params)

      exit_code = nil
      command_output = ''
      logfile = command.last.sub(/\.pdf$/, '.html')
      html_started = false
      html_finished = false

      # Capture rendered HTML the same way we get it for free with phantomjs
      File.open(logfile, 'w') do |log|
        Open3.popen2e(*command) do |_, out_err, wait_thread|
          out_err.each {|line|
            html_started = true if line.match(/<head\b/i)
            html_finished = true if html_started && line.match(/<\/body>/i)

            if html_started && !html_finished
              log.write(line)
            else
              Rails.logger.debug "WKHTMLTOPDF: #{line.rstrip}"
            end
          }
          exit_code = wait_thread.value.exitstatus
        end
      end

      File.write('/tmp/last-wkhtmltopdf-call', command.join(' '))  #TODO: remove
      if exit_code == 0
        command.last
      else
        Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_output}"
        raise ExportException, command_output
      end
    end

    def convert_h_tags(doc)
      # Accepts text or Nokogiri document
      if !doc.respond_to?(:xpath)
        doc.gsub!(/\r\n/, '')
        #NOTE: This situation needs to be handled better because this method
        #changes $doc by reference if it's already a Nokogiri doc, despite
        #how it also returns the resulting doc
        return '' if doc == '' || doc == '<br>'

        doc = Nokogiri::HTML.parse(doc)
      end

      doc.xpath("//h1 | //h2 | //h3 | //h4 | //h5 | //h6").each do |node|
        #BUG: This loses any classes the H tag had.
        node['class'] = node['class'].to_s + " new-h#{ node.name.match(/h(\d)/)[1] }"
        node.name = 'div'
      end

      doc
    end

    def inject_doc_styles(doc)
      #NOTE: Using doc.css("center").wrap(...) here broke annotations
      doc.css("center").add_class("Case-header")
      doc.css("p").add_class("Item-text")
      cih_selector = '//div[not(ancestor::center) and contains(concat(" ", normalize-space(@class), " "), "new-h2")]'
      doc.xpath(cih_selector).wrap('<div class="Case-internal-header"></div>')
    end

    def forwarded_cookies(params)
      skip_list = []
      if params[:export_format] == 'pdf'
        skip_list << %w(
                     print_margin_top,
                     print_margin_right,
                     print_margin_bottom,
                     print_margin_left,
                    )
      end
      cookies = forwarded_cookies_hash(params).except(*skip_list.flatten)
      cookies.map {|k,v|
        "--cookie #{k} #{encode_cookie_value(v)}" if v.present?
      }.join(' ')
    end

    def forwarded_cookies_hash(params)
      # This performs the reverse of export.js:init_user_settings() by mapping
      # form field names to cookie names while also translating values.
      # Ideally we would just consolidate the form field names to match cookie names
      # as well as no longer using multiple forms of true and false.
      # Note: We don't send marginsize because margins are set via the wkhtmltopdf command line
      cookies = {'export_format' => params[:export_format]}

      FORM_COOKIE_MAP.each do |field, v|
        if params[field].present?
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

    def generate_toc_levels_css(depth)  #_doc
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

    def generate_toc_general_css(params)  #_doc
      "font-family: #{params['fontface_mapped']}; " +
      "font-size: #{params['fontsize_mapped']};"
    end

    def render_toc(params)  #_doc
      vars = {
        :title => params['item_name'],
        :general_css => generate_toc_general_css(params),
        :toc_levels_css => generate_toc_levels_css(params['toc_levels']),
      }
      ApplicationController.new.render_to_string(
        "playlists/toc.xsl",
        :layout => false,
        :locals => vars,
        )  #.tap {|x| Rails.logger.debug "TOCBLOCK: #{x}"}
    end

    def generate_toc_options(params)  #_doc
      options = ["--no-outline"]
      if params['toc_levels'].present?
        options << "toc --xsl-style-sheet " + toc_file(params)
      end
      options
    end

    def toc_file(params)  #_doc
      #NOTE: There may be a risk tempfile will unlink this file before it gets used,
      #so we probably need a regular IO file that we unlink or clear some other way.
      file = Tempfile.new(['export_toc', '.xsl'])
      file.write render_toc(params)
      file.close
      file.path
    end

    def pdf_page_options(params)  #_pdf
      [
        "--no-stop-slow-scripts --debug-javascript",  # --javascript-delay 1000
        "--window-status annotation_load_complete",
        "--print-media-type",  # NOTE: DOC export ignores this.
      ]
    end

    def pdf_command(request_url, params)  #_pdf
      #request_url is the full request URI that is posting TO this page. We need
      # pieces of that that to construct the URL we are going to pass to wkhtmltopdf
      global_options = %w[margin-top margin-right margin-bottom margin-left].map {|name|
        "--#{name} #{params[name]}"
      }.join(' ')

      toc_options = generate_toc_options(params)
      target_url = get_target_url(request_url)
      page_options = pdf_page_options(params)
      cookie_string = forwarded_cookies(params)
      output_file_path = output_file_path(params)

      prep_output_file_path(output_file_path)

      [
        'wkhtmltopdf',
        global_options,
        toc_options,
        'page',
        target_url,
        page_options,
        cookie_string,
        output_file_path,  #This always has to be last in this array
      ].flatten.join(' ').split
    end

    def prep_output_file_path(output_file_path)  #_pdf or _base if useful there
      FileUtils.mkdir_p(File.dirname(output_file_path))
    end

    def get_target_url(request_url)  #_base
      page_name = request_url.match(/\/playlists\//) ? 'export_all' : 'export'
      request_url.sub(/export_as$/, page_name)
    end

    def encode_cookie_value(val)
       ERB::Util.url_encode(val)
    end

  end
end
