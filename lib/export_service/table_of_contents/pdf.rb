module ExportService
  module TableOfContents
    module PDF

      module_function

      def generate(request_url, params)
        options = ["--no-outline"]
        if params['toc_levels'].present? && request_url =~ %r(/playlists/\d+)
          options += %w{toc --xsl-style-sheet} + [toc_file(params)]
        end
        options
      end

      def toc_file(params)
        filename = "#{params['base_dir']}/toc.xsl"
        File.write(filename, render_toc(params))
        filename
      end

      def render_toc(params)
        vars = {
          :title => params['item_name'],
          :general_css => generate_toc_general_css(params),
          :toc_levels_css => generate_toc_levels_css(params['toc_levels']),
        }
        ApplicationController.new.render_to_string(
          "playlists/toc.xsl",
          :layout => false,
          :locals => vars,
          )
      end

      def generate_toc_general_css(params)
        font_csv = params['fontface_mapped'].split(/,\s*/).map do |f|
          f.index(' ') ? ('"' + f + '"') : f
        end.join(',')
        "font-family: #{font_csv}; font-size: #{params['fontsize_mapped']};"
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

    end
  end
end
