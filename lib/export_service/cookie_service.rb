module ExportService

  # This is a quick and dirty extract service refactoring from the PlaylistExporter model

  class CookieService

    # No translation value here means we just pass the form field value straight through
    # Some cookies are just here to make them available to PhantomJS
    # If you want to forwad a cookie from the print header all the way through to one
    # of the exporters, it needs to be listed here.
    COMMON_TRANS = {'yes' => 'true', 'no' => 'false'}

    FORM_COOKIE_MAP = {
      'printtitle' => {'cookie_name' => 'print_titles', 'trans' => COMMON_TRANS },
      'printparagraphnumbers' => {'cookie_name' => 'print_paragraph_numbers', 'trans' => COMMON_TRANS },
      'printannotations' => {'cookie_name' => 'print_annotations', 'trans' => COMMON_TRANS },
      'printlinks' => {'cookie_name' => 'print_links', 'trans' => COMMON_TRANS },
      'hiddentext' => {'cookie_name' => 'hidden_text_display', 'trans' => {'show' => 'true', 'hide' => 'false'} },
      'printhighlights' => {'cookie_name' => 'print_highlights'},
      'toc_levels' => {'cookie_name' => 'toc_levels'},
      'fontface' => {'cookie_name' => 'print_font_face'},
      'fontsize' => {'cookie_name' => 'print_font_size'},
      'fontface_mapped' => {'cookie_name' => 'print_font_face_mapped'},
      'fontsize_mapped' => {'cookie_name' => 'print_font_size_mapped'},
      'margin-top' => {'cookie_name' => 'print_margin_top'},
      'margin-right' => {'cookie_name' => 'print_margin_right'},
      'margin-bottom' => {'cookie_name' => 'print_margin_bottom'},
      'margin-left' => {'cookie_name' => 'print_margin_left'},
      '_h2o_session' => {'cookie_name' => '_h2o_session'},
    }

    def self.forwarded_cookies_hash(params)
      # This performs the reverse of export.js:init_user_settings() by mapping
      # form field names to cookie names while also translating values.
      # It was too much work to just consolidate expected values for cookies and
      # and the form.
      cookies = {'export_format' => params['export_format']}

      FORM_COOKIE_MAP.each do |field, mapping|
        param = params[field]
        next if param.to_s == ''

        if mapping['trans']
          cookie_value = mapping['trans'][param]
          if cookie_value.nil?
            Rails.logger.warn "Couldn't find expected cookie mapping for param: #{field}"
          end
        else
          cookie_value = param
        end

        cookies[mapping['cookie_name']] = cookie_value if cookie_value
      end

      cookies
    end

    def self.forwarded_pdf_cookies(params)
      skip_list = %w[
                     print_margin_top
                     print_margin_right
                     print_margin_bottom
                     print_margin_left
                    ]
      cookies = forwarded_cookies_hash(params).except(*skip_list.flatten)
      cookies.map {|k,v|
        "--cookie #{k} #{encode_cookie_value(v)}" if v.present?
      }.join(' ')
    end

    def self.phantomjs_options_file(directory, params)  #_doc
      filename = File.join(directory, 'phantomjs-args.json')
      File.write(filename, forwarded_cookies_hash(params).to_json)
      filename
    end

    def self.encode_cookie_value(val)
      ERB::Util.url_encode(val)
    end

  end

end
