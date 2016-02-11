module ExportService
  module TableOfContents
    module PDF

      module_function

      def generate(request_url, params)
        options = ["--no-outline"]
        if params['toc_levels'].present? && request_url =~ %r(/playlists/\d+)
          options << "toc --xsl-style-sheet " + toc_file(params)
        end
        options
      end

      def toc_file(params)  #_pdf
        #NOTE: There may be a risk tempfile will unlink this file before it gets used,
        #so we probably need a regular IO file that we unlink or clear some other way.
        file = Tempfile.new(['export_toc', '.xsl'])
        file.write render_toc(params)
        file.close
        file.path
      end

      def render_toc(params)  #_pdf
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

      def generate_toc_general_css(params)  #_pdf
        "font-family: #{params['fontface_mapped']}; " +
          "font-size: #{params['fontsize_mapped']};"
      end

      def generate_toc_levels_css(depth)  #_pdf
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

    end
  end
end
