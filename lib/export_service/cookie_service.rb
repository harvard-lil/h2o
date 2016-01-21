module ExportService

  # This is a quick and dirty extract service refactoring from the PlaylistExporter model

  class CookieService

    # No translation value here means we just pass the form field value straight through
    # Some cookies are just here to make them available to PhantomJS
    # If you want to forwad a cookie from the print header all the way through to one
    # of the exporters, it needs to be listed here.
    FORM_COOKIE_MAP = {
      '_h2o_session' => {'cookie_name' => '_h2o_session'},
      'printtitle' => {'cookie_name' => 'print_titles', 'cookval' => 'false', 'formval' => 'no', },
      'printparagraphnumbers' => {'cookie_name' => 'print_paragraph_numbers', 'cookval' => 'false', 'formval' => 'no', },
      'printannotations' => {'cookie_name' => 'print_annotations', 'cookval' => 'true', 'formval' => 'yes', },
      'printlinks' => {'cookie_name' => 'print_links', 'cookval' => 'true', 'formval' => 'yes', },
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

    def self.forwarded_cookies_hash(params)  #_both
      # This performs the reverse of export.js:init_user_settings() by mapping
      # form field names to cookie names while also translating values.
      # Ideally we would just consolidate the form field names to match cookie names
      # as well as no longer using multiple forms of true and false.
      # BUG: This needs to translate all valid values for each cookie. Right now,
      #   it only does one of them, but export.js only looks for values that
      #   contradict the default behavior of the form and its input change handlers.
      #   That causes some pretty confusing behavior when you're debugging.
      cookies = {'export_format' => params[:export_format]}
      FORM_COOKIE_MAP.each do |field, v|
        next unless params[field].present?

        if params[field] == v['formval']
          # translate form value to its cookie representation
          cookies[v['cookie_name']] = v['cookval']
        elsif v['cookval'].nil?
          # pass the form value through, unchanged
          cookies[v['cookie_name']] = params[field]
        end
      end
      cookies
    end

    def self.phantomjs_options_file(params)  #_doc
      file = Tempfile.new(['phantomjs-args-', '.json'])
      file.write forwarded_cookies_hash(params).to_json
      file.close
      file  #.tap {|x| Rails.logger.debug "JSON: #{x.path}" }
    end

    def self.encode_cookie_value(val)
       ERB::Util.url_encode(val)
    end


  end

end
