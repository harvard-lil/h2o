namespace :annotations do
  desc 'Compare Ruby\'s text to what Vue returns'
  task(:compare_ruby_text_to_vue => :environment) do
    [Case, TextBlock].each do |klass|
      i = 0
      count = klass.count
      klass.find_each do |inst|
        i += 1
        ruby_text = HTMLUtils.parse(inst.content).text
        vue_text = HTMLUtils.parse(Vue::SSR.render(inst.content)).text
        diffs = Differ.get_diffs(ruby_text, vue_text).select { |d| d[0] != :equal }
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

  desc 'Identify annotations with paragraph based offsets that don\'t exist in the text'
  task(:impossible => :environment) do
    annotatable = {Case => {}, TextBlock => {}}
    annotatable.keys.each do |klass|
      puts "Calculating #{klass.name.pluralize}"
      klass.annotated.find_each do |instance|
        annotatable[klass][instance.id] = []
        nodes = HTMLUtils.parse(instance.content).at('body').children
        instance.annotations.find_each do |a|
          error = [:start, :end].reduce(false) { |error, pos|
            graph = nodes[a["#{pos}_paragraph"]]
            if error
              error
            elsif graph.nil?
              "p = #{a["#{pos}_paragraph"]} but nodes.max = #{nodes.length - 1}"
            elsif a["#{pos}_offset"] > AnnotationConverter.get_node_length(graph)
              len = AnnotationConverter.get_node_length(graph)
              "p\##{a["#{pos}_paragraph"]}.length = #{len} but offset = #{a["#{pos}_offset"]}"
            end
          }
          annotatable[klass][instance.id] << error if error
        end
      end
      puts "#{annotatable[klass].values.select(&:present?).length} impossible / #{annotatable[klass].length} total annotated\n"
    end
  end
end
