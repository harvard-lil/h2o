namespace :annotations do
  desc 'Compare Ruby offset calculations to JS calculations'
  task(:compare_ruby_to_js => :environment) do
    require 'json'
    require 'tempfile'

    build = Tempfile.new('webpack_ssr_build')
    begin
      puts "Building resource_ssr.js"
      `bin/webpack --entry #{Rails.root.join('app','webpacker','packs','resource_ssr.js')} --output #{build.path} --config #{Rails.root.join('config','webpack','test.js')} --target node --mode production`
      puts "Build complete; selecting cases"

      node_cmd = "node -r #{Rails.root.join('test','javascript','mocha_setup.js')} #{build.path}"
      counts = [0, 0]
      Case.order(id: :desc).limit(500).each do |c|
        ruby_breakpoints = AnnotationConverter.nodes_to_breakpoints(HTMLHelpers.parse_and_process_nodes(c.content))
        js_breakpoints = IO.popen(node_cmd, 'r+') do |io|
          io.write({content: c.content}.to_json)
          io.close_write
          JSON.parse(io.read)
        end

        counts[0] += 1
        if(ruby_breakpoints.last != js_breakpoints.last)
          counts[1] += 1
          puts "#{c.id} | #{ruby_breakpoints.last - js_breakpoints.last}"
        end
      end
      puts "Total: #{counts[0]}, Diff: #{counts[1]}"
    ensure
      build.close
      build.unlink
    end
  end

  desc 'Compare Ruby\'s Nokogiri text to what Vue returns'
  task(:compare_nokogiri_text_to_vue => :environment) do
    require 'diff/lcs'
    limit = 500
    count = 0
    ids = []
    Case.order(id: :desc).limit(limit).each do |c|
      count += 1
      ruby_text = Content::Resource.new(resource: c).paragraph_nodes.text.gsub("\r\n", "\n")
      vue_text = Nokogiri::HTML(Vue::SSR.render(c.content)).text
      diff = Diff::LCS.diff(ruby_text, vue_text)
      puts "\n\n*** Case #{c.id}, #{count} of #{limit}"
      if diff.length > 0
        puts "***************", DiffLCS.format(diff)
      end
    end
  end
end
