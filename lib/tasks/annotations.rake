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
        ruby_breakpoints = AnnotationConverter.paragraph_nodes_to_breakpoints(Content::Resource.new(resource: c).paragraph_nodes)
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

  desc 'Find Cases Whose Annotation Structure May Change'
  task(:annotation_shifted => :environment) do
    old_unnest = lambda do |html|
      html
        .xpath('//div')
        .each { |el| el.replace el.children }
      html
    end

    old_filter_empty_nodes = lambda do |nodes|
      nodes.each do |node|
        if ! node.nil? && node.children.empty?
          nodes.delete(node)
        end
      end
      nodes
    end

    total = Case.annotated.reduce(0) do |memo, c|
      new_html = Nokogiri::HTML(c.content) {|config| config.strict.noblanks}
      new = HTMLHelpers.process_p_nodes(new_html).map(&:to_s)

      old_html = Nokogiri::HTML(c.content) {|config| config.strict.noblanks}
      old = [HTMLHelpers.method(:strip_comments!),
             old_unnest,
             HTMLHelpers.method(:empty_ul_to_p!),
             HTMLHelpers.method(:wrap_bare_inline_tags!),
             HTMLHelpers.method(:get_body_nodes_without_whitespace_text),
             old_filter_empty_nodes].reduce(old_html) { |memo, fn| fn.call(memo) }.map(&:to_s)

      memo += 1 if new != old
      memo
    end

    puts "There are #{total} cases whose annotation structure might change"
  end
end
