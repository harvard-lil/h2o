module Export

  def export_content(content_node)

    @content_node = content_node
    @include_annotations = (params["annotations"] == "true")
    file_path = Rails.root.join("tmp/export-#{Time.now.utc.iso8601}-#{SecureRandom.uuid}.docx")

    if H2o::Application.config.pandoc_export
      html = render_to_string(action: 'export_pandoc', layout: 'export', include_annotations: @include_annotations)

      # remove image tags
      nodes = Nokogiri::HTML.fragment(html)
      nodes.css('img').each do | img |
          img.remove
      end

      # legacy escaping of backslashes
      html = nodes.to_s
      html.gsub! /\\/, '\\\\\\'

      flags = [
          '--from html',
          '--to docx',
          '--reference-doc "lib/pandoc/reference.docx"',
          '--docx-preserve-style',
          "--output #{file_path}"
      ]
      cmd = "pandoc #{flags.join(' ')}"
      stdout, stderr, status = Open3.capture3(cmd, stdin_data: html.to_s)
      if !status.success?
        raise Exception.new("Pandoc export failed, with: #{stderr}".truncate(100))
      end


    else
      html = render_to_string(layout: 'export', include_annotations: @include_annotations)

      # remove image tags
      nodes = Nokogiri::HTML.fragment(html)
      nodes.css('img').each do | img |
          img.remove
      end

      # legacy escaping of backslashes
      html = nodes.to_s
      html.gsub! /\\/, '\\\\\\'

      # Htmltoword doesn't let you switch xslt. So we need to manually do it.
      if @include_annotations
        Htmltoword.config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/with-annotations'
      else
        Htmltoword.config.default_xslt_path = Rails.root.join 'lib/htmltoword/xslt/no-annotations'
      end
      Htmltoword::Document.create_and_save(html, file_path)
    end

    send_file file_path, type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', filename: export_filename(content_node, 'docx', @include_annotations), disposition: :inline
  end

  private

  def export_filename content_node, format, annotations=false
    suffix = annotations ? '_annotated' : ''
    helpers.truncate(content_node.title, length: 45, omission: '-', separator: ' ') + suffix + '.' + format
  end

end
