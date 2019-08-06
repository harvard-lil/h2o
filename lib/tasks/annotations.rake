# coding: utf-8
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

  desc 'Generate a spreadsheet containing details about annotations and the effect the global positioning migration might have on them'
  task(:migration_report => :environment) do
    # TODO
    # - Finde paragraphs of identical lengths when impossible offsets are provided
    require 'csv'
    include Rails.application.routes.url_helpers
    CSV.open(Rails.root.join("migration-report-date-based-utils.csv"), "w") do |csv|
      # Column headers
      csv << ["ID",
              "Resource",
              "Casebook Owner",
              "Possible?",
              "Probable Start?",
              "Probable End?",
              "Selected Text",
              "P Count",
              "Start P Index",
              "Start Offset",
              "Start P Length",
              "End P Index",
              "End Offset",
              "End P Length"]

      [Case, TextBlock].each do |klass|
        puts "Calculating #{klass.name.pluralize}"
        klass.annotated.find_each do |instance|
          # cache these to reduce DB access and parsing time
          utils = nil
          nodes = nil
          resource = nil

          instance.annotations.order(created_at: :asc).find_each do |a|
            # invalidate cached items if needed
            date = [a.created_at, HTMLUtils::V3::EFFECTIVE_DATE].min
            new_utils = HTMLUtils.at(date)
            if new_utils != utils
              utils = new_utils
              nodes = HTMLUtils.parse(utils.sanitize(instance.raw_content.content)).at('body').children
            end
            resource = a.resource if resource&.id != a.resource_id

            possible = !impossible?(nodes, a)
            text = possible ? get_selected_text(nodes, a) : ""
            csv << [a.id,
                    resource_path(resource.casebook, resource),
                    resource.casebook.owner&.display_name,
                    possible,
                    possible && (a.start_offset == 0 || boundary_char?(AnnotationConverter.get_node_text(nodes[a.start_paragraph])[a.start_offset-1])),
                    possible && (a.end_offset == AnnotationConverter.get_node_length(nodes[a.end_paragraph]) || boundary_char?(AnnotationConverter.get_node_text(nodes[a.end_paragraph])[a.end_offset])),
                    text.truncate(50, omission: "{…}#{text.last(25)}"),
                    nodes.length,
                    *[:start, :end].reduce([]) { |vals, pos|
                      vals.concat([a["#{pos}_paragraph"],
                                   a["#{pos}_offset"],
                                   possible ? AnnotationConverter.get_node_length(nodes[a["#{pos}_paragraph"]]) : nil])
                    }]
          end
        end
      end
    end
  end

  def impossible? nodes, annotation
    [:start, :end].reduce(false) { |impossible, pos|
      impossible ||
        nodes[annotation["#{pos}_paragraph"]].nil? ||
        annotation["#{pos}_offset"] > AnnotationConverter.get_node_length(nodes[annotation["#{pos}_paragraph"]])
    }
  end
  
  def get_selected_text nodes, annotation
    graphs = nodes[annotation.start_paragraph..annotation.end_paragraph].map { |node| AnnotationConverter.get_node_text(node) }
    if graphs.length == 1
      i = annotation.end_offset
    else
      i = -1
      graphs[graphs.length-1] = graphs.last[0..annotation.end_offset]
    end
    graphs[0] = graphs[0][annotation.start_offset..i]
    graphs.join('')
  end

  def boundary_char? char
    !char.match(/[a-zA-Z]/)
  end
end
