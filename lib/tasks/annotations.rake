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
end
