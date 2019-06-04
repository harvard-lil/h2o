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
    [Case, TextBlock].each do |klass|
      i = 0
      count = klass.count
      klass.find_each do |inst|
        i += 1
        ruby_text = HTMLFormatter.parse(inst.content).text
        vue_text = HTMLFormatter.parse(Vue::SSR.render(inst.content)).text
        diffs = DiffHelpers.get_diffs(ruby_text, vue_text).select { |d| d[0] != :equal }
        puts "*** #{klass.name} id: #{inst.id}; #{i} of #{count} #{diffs.blank? ? "(identical)" : ""}"
        if diffs.present?
          puts diffs.map { |a, b, c, d|
            [a, "",
             "<<<< Ruby", ruby_text[c.min - 10..c.max + 10],
             "", ">>>> Vue",
             vue_text[d.min - 10..d.max + 10],
             ""]
          }
        end
      end
    end
  end
end
