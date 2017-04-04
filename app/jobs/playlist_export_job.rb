require 'tempfile'
require 'uri'
require 'shellwords'

# TODO: This export implementation has been disabled. It must be reimplemented in a more performant way.


class PlaylistExportJob < ApplicationJob
  def logger; Rails.logger; end
  rescue_from Exception do |e|
    logger.error "Export error: #{e.inspect}"
    e.backtrace.each &logger.method(:debug)
    raise e
  end

  class ExportException < StandardError; end

  def perform(opts)
    logger.debug "Export job is running."
    request_url = opts[:request_url]
    params = opts[:params]
    email_address = opts[:email_to]

    #required for owners to export their own private content
    params.merge!(:_h2o_session => opts[:session_cookie])
    export_format = params[:export_format]
    if export_format == 'docx'
      exported_file = export_as_docx(request_url, params)
    elsif export_format == 'pdf'
      exported_file = export_as_pdf(request_url, params)
    else
      raise ExportException, "Unsupported export_format '#{export_format}'"
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
    Notifier.export_download_link(content_path, email_address).deliver_now
  end

  def export_as_docx(request_url, params)  #_doc
    out_path = output_file_path(params)
    convert_to_docx(generate_html(request_url, params), out_path)
    out_path
  end

  def output_file_path(params)  #_base
    base_dir = Rails.root.join('public/exports')
    FileUtils.mkdir(base_dir) unless File.exist?(base_dir)

    out_dir = Dir::Tmpname.create(params[:id], base_dir) {|path| path}
    FileUtils.mkdir(out_dir) unless File.exist?(out_dir)

    filename = (params[:item_name].to_s || "download").parameterize.underscore
    out_dir + '/' + filename + '.' + params[:export_format]
  end

  def create_phantomjs_options_file(directory, params)
    ExportService::Cookies.phantomjs_options_file(directory, params)
  end

  # TODO: This HTML generation must be implemented without requiring a headless browser.
  def generate_html(request_url, params)
    out_path = Rails.root.join "tmp/export-#{SecureRandom.uuid}.html"

    if Rails.env.in? %w{test development}
      File.write out_path, <<-HTML
        <html>
          <body>
            <h1>TEST EXPORT:  #{params['item_name']}</h1>
            <h2>Export has been disabled. This is a temporary output to test the interface.</h2>
            <p>Controller: #{params['controller']}</p>
            <p>Format: #{params['export_format']}</p>
          </body>
        </html>
      HTML
      return out_path
    end
    raise NotImplementedError
    # target_url = get_target_url(request_url)
    # out_file.sub!(/#{File.extname(out_file)}$/, '.html')
    #
    # options_tempfile = create_phantomjs_options_file(
    #   File.dirname(out_file),
    #   params
    #   )
    #
    # command = [
    #            'phantomjs',
    #            # '--debug=true',
    #            'app/assets/javascripts/phantomjs-export.js',
    #            target_url,
    #            out_file,
    #            options_tempfile,
    #           ]
    # Rails.logger.warn command.join(' ')
    #
    # exit_code = nil
    # command_output = []
    # Open3.popen2e(*command) do |_, out_err, wait_thread|
    #   out_err.each {|line|
    #     Rails.logger.warn "PHANTOMJS: #{line.rstrip}"
    #     command_output << line
    #   }
    #   exit_code = wait_thread.value.exitstatus
    # end
    # command_text = command_output.join("\n")
    #
    # if exit_code == 0
    #   out_file.tap {|x| Rails.logger.warn "Created #{x}" }
    # else
    #   Rails.logger.warn "Export failed for command: #{command.join(' ')}\nOutput: #{command_text}"
    #   raise ExportException, command_text
    # end
  end

  # AIUI this is simply a .docx header instructing Word to parse encoded HTML.
  # No conversion is needed for this approach, but it should be reevaluated
  def convert_to_docx(in_path, out_path)
    env = if Rails.env == 'test'
      {'HTMLTOWORD_DETERMINISTIC' => 'true'}
    else
      {}
    end
    command = %W{htmltoword #{in_path} #{out_path}}
    if system env, command.shelljoin + " >> #{Rails.root.join 'log/htmltoword.log'} 2>&1"
      out_path
    else
      raise ExportException, $?.inspect
    end
  end

  def html_head_open?(line)  #_pdf
    line.match(/<head\b/i)
  end

  def html_body_close?(line)  #_pdf
    line.match(/<\/body>/i)
  end

  def export_as_pdf(request_url, params)  #_pdf
    in_path = generate_html(request_url, params)

    command = pdf_command(in_path, request_url, params)
    out_path = command.last
    logger.debug "Running PDF generation: #{command.inspect}"
    if system command.shelljoin + " >> #{Rails.root.join 'log/wkhtmltopdf.log'} 2>&1"
      if Rails.env == 'test'
        # Remove creation date for deterministic tests
        IO.binwrite(out_path, File.open(out_path, 'r:ASCII-8BIT') {|f| f.read.sub /\/CreationDate \(D:[^)]*\)/, '' })
      end
      return out_path
    else
      raise ExportException, $?.inspect
    end
    # Rails.logger.warn command.join(' ')

    # exit_code = nil
    # command_output = []
    # html_file = command.last.sub(/\.pdf$/, '.html')
    # html_has_started = false
    # html_has_finished = false
    # Since we will generate HTML statically, this is unnecessary.
    # File.open(html_file, 'w') do |log|
    #   # In addition to running the exporter, this captures the rendered HTML
    #   # the exporter is seeing, the same way we get it for free with phantomjs.
    #   Open3.popen2e(*command) do |_, out_err, wait_thread|
    #     out_err.each do |line|
    #       html_has_started = true if html_head_open?(line)
    #       html_has_finished = true if html_body_close?(line)
    #
    #       if html_has_started && (!html_has_finished || html_body_close?(line))
    #         log.write(line)
    #       else
    #         Rails.logger.warn "WKHTMLTOPDF: #{line.rstrip}"
    #         command_output << line
    #       end
    #     end
    #
    #     exit_code = wait_thread.value.exitstatus
    #   end
    # end
    # command_text = command_output.join
    #
    # if exit_code == 0
    #   out_path
    # else
    #   raise ExportException
    # end
  end

  def convert_h_tags(doc)
    # Convert H tags to divs to let us control the H tags in a document, which
    #   controls the H tags that are used on the table of contents, both in
    #   Word export and in the JavaScript TOC code.
    # Accepts a string or Nokogiri document
    if !doc.respond_to?(:xpath)
      doc.gsub!(/\r\n/, '')
      #NOTE: This situation needs to be handled better because this method
      #changes $doc by reference if it's already a Nokogiri doc, despite
      #how it also returns the resulting doc
      return '' if doc.in?(['', '<br>'])
      doc = Nokogiri::HTML.parse(doc)
    end

    doc.xpath("//h1 | //h2 | //h3 | //h4 | //h5 | //h6").each do |node|
      # NOTE: The nxp class is used to exclude this div from xpaths counts (e.g. /div[3])
      #   because we are changing the number of divs in a document
      h_level = node.name.match(/h(\d)/)[1]
      node['class'] = node['class'].to_s + " new-h#{h_level} nxp"
      node.name = 'div'
    end

    doc
  end

  def inject_doc_styles(doc)  #_both
    # NOTE: Using doc.css("center").wrap(...) here broke annotations, probably because
    #   it added another layer to the local DOM, which meant xpath_start and/or xpath_end
    #   values in the relevant annotation didn't match up with the DOM any more.
    doc.css("center").add_class("Case-header")
    doc.css("p").add_class("Item-text")

    cih_selector = '//div[not(ancestor::center) and contains(concat(" ", normalize-space(@class), " "), "new-h2")]'
    doc.xpath(cih_selector).each do |el|
      # Word style classes only work when they are the first class for a given element.
      el['class'] = "Case-internal-header " + el['class'].to_s
    end
  end

  def pdf_page_options(params)  #_pdf
    [
      '--no-stop-slow-scripts',
      '--debug-javascript',
      '--javascript-delay 1000',
      '--window-status annotation_load_complete',
      '--print-media-type',  # NOTE: DOC export ignores this.
    ]
  end

  # TODO: make this run the same static html as the .doc exporter
  def pdf_command(in_path, request_url, params)  #_pdf
    #request_url is the full request URI that is posting TO this page. We need
    # pieces of that that to construct the URL we are going to pass to wkhtmltopdf
    global_options = %w[margin-top margin-right margin-bottom margin-left].map {|name|
      %W{--#{name} #{params[name]}}
    }.flatten

    out_path = output_file_path(params)
    toc_params = params.merge('base_dir' => File.dirname(out_path))
    toc_options = ExportService::TableOfContents::PDF.generate(request_url, toc_params)

    page_options = pdf_page_options(params)

    prep_output_file_path(out_path)
    [
      'wkhtmltopdf',
      *global_options,
      *toc_options,
      in_path,
      out_path,  #This always has to be last in this array
    ]
  end

  def prep_output_file_path(out_path)  #_pdf or _base if useful there
    FileUtils.mkdir_p(File.dirname(out_path))
  end

  def get_target_url(request_url)  #_base
    page_name = request_url.match(/\/playlists\//) ? 'export_all' : 'export'
    request_url.sub(/export_as$/, page_name)
  end
end
