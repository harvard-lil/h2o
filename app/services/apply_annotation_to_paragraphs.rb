## This class applies an annotation to it's corresponding paragraph nodes (created by nokogiri). An annotation can span multiple paragraphs.
class ApplyAnnotationToParagraphs
  attr_accessor :annotation, :paragraph_node, :paragraph_index, :export_footnote_index, :start_paragraph, :end_paragraph, :start_offset, :end_offset, :kind, :id, :content

  def self.perform(params)
    new(params).perform
  end

  def initialize(params)
    @annotation = params[:annotation]
    @paragraph_node = params[:paragraph_node]
    @paragraph_index = params[:paragraph_index]
    @export_footnote_index = params[:export_footnote_index]
    @start_paragraph = annotation.start_paragraph
    @end_paragraph = annotation.end_paragraph
    @start_offset = annotation.start_offset
    @end_offset = annotation.end_offset
    @kind = annotation.kind
    @id = annotation.id
    @content = annotation.content
  end

  def perform
    # This is set for annotations that span multiple paragraphs. After the annotation is applied to each paragraph the character size of the paragraph that is added to this variable so that the next paragraph starts are the right spot.
    paragraph_offset = 0

    if full_paragraph?
      return paragraph_node.children = annotate_html(paragraph_node.inner_html, paragraph_offset)
    end

    noninitial = paragraph_index != start_paragraph

    paragraph_node.traverse do |node|
      next unless node.text? && node.parent['data-exclude-from-offset-calcs'] != 'true'

      if noninitial
        if middle_paragraph?(node, paragraph_offset)
          wrap_middle_paragraph(node, paragraph_offset)
        else
          wrap_last_paragraph(node, paragraph_offset)
          break
        end
      else
        if paragraph_offset_ready?(node, paragraph_offset)
          if only_paragraph? && partial_paragraph?(node, paragraph_offset)
            selected_text = annotate_html(node.text[start_offset - paragraph_offset...end_offset - paragraph_offset], paragraph_offset)
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{selected_text}#{node.text[end_offset - paragraph_offset..-1]}"
            break
          else
            noninitial = true
            selected_text = annotate_html(node.text[start_offset - paragraph_offset..-1], paragraph_offset)
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{selected_text}"
          end
        end
      end
      paragraph_offset += node.text.length
    end
  end

  private

  def annotate_html(selected_text, paragraph_offset)
    is_head = start_paragraph == paragraph_index && start_offset >= paragraph_offset
    is_tail = end_paragraph == paragraph_index && end_offset <= paragraph_offset + selected_text.length

    cssClasses = ['annotate',
                  ({'elide' => 'elided',
                    'highlight' => 'highlighted'}[kind] || kind)]

    cssClasses << 'head' if is_head
    cssClasses << 'tail' if is_tail

    footnote_style_attribute = H2o::Application.config.pandoc_export ? 'custom-style="Footnote Reference"' : 'msword-style="FootnoteReference"'
    replacement_style_attribute = H2o::Application.config.pandoc_export ? 'custom-style="Replacement Text"' : 'msword-style="ReplacementText"'
    highlight_style_attribute = H2o::Application.config.pandoc_export ? 'custom-style="Highlighted Text"' : ''
    marker = is_tail && ['link', 'note'].include?(kind) ? "<span #{footnote_style_attribute} data-exclude-from-offset-calcs='true'>#{'*' * export_footnote_index}</span>" : ''

    case kind
    when 'link' then
      "<a href='#{escaped_content}' class='#{cssClasses.join(' ')}'>#{selected_text}</a>#{marker}"
    when 'note' then
      "<span class='#{cssClasses.join(' ')}'>#{selected_text}</span>#{marker}"
    when 'replace' then
      (!H2o::Application.config.pandoc_export ? "<span class='annotate replaced'>#{selected_text}</span>" : '') + (is_head ? "<span #{replacement_style_attribute} data-exclude-from-offset-calcs='true'>#{escaped_content}</span>" : '')
    when 'elide' then
      if H2o::Application.config.pandoc_export
        is_head ? '<span custom-style="Elision">[ … ]</span>' : ''
      else
        "<span class='#{cssClasses.join(' ')}'>#{selected_text}</span>"
      end
    when 'highlight' then
      "<span class='#{cssClasses.join(' ')}' #{highlight_style_attribute}>#{selected_text}</span>"
    else
      raise Exception.new("Unhandled annotation type: #{kind}")
    end
  end

  def escaped_content
    ApplicationController.helpers.send(:html_escape, content)
  end

  def middle_paragraph?(node, paragraph_offset)
    paragraph_index != end_paragraph || end_offset > paragraph_offset + node.text.length
  end

  def wrap_middle_paragraph(node, paragraph_offset)
    node.replace annotate_html(node.text, paragraph_offset)
  end

  # This is the last paragraph, apply the annotation to the remaining characters.
  def wrap_last_paragraph(node, paragraph_offset)
    selected_text = annotate_html(node.text[0...end_offset - paragraph_offset], paragraph_offset)
    node.replace "#{node.text[0...0]}#{selected_text}#{node.text[end_offset - paragraph_offset..-1]}"
  end

  # If the annotation doesn't start at the first character, loop through and add to the paragraph_offset so that you can start at the right place.
  def paragraph_offset_ready?(node, paragraph_offset)
    paragraph_offset + node.text.length > start_offset
  end

  def only_paragraph?
    paragraph_index == end_paragraph
  end

  def partial_paragraph?(node, paragraph_offset)
    paragraph_offset + node.text.length >= end_offset
  end

  def full_paragraph?
    (paragraph_index != start_paragraph || start_offset == 0) &&
      (paragraph_index != end_paragraph || end_offset == paragraph_node.text.length)
  end
end
