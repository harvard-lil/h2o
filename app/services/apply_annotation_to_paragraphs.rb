## This class applies an annotation to it's corresponding paragraph nodes (created by nokogiri). An annotation can span multiple paragraphs. 
class ApplyAnnotationToParagraphs
  attr_accessor :annotation, :paragraph_node, :paragraph_index, :export_footnote_index, :editable, :exporting, :start_paragraph, :end_paragraph, :start_offset, :end_offset, :kind, :id, :content, :include_annotations

  def self.perform(params)
    new(params).perform
  end

  def initialize(params)
    @annotation = params[:annotation]
    @paragraph_node = params[:paragraph_node]
    @paragraph_index = params[:paragraph_index]
    @export_footnote_index = params[:export_footnote_index]
    @editable = params[:editable]
    @exporting = params[:exporting]
    @include_annotations = params[:include_annotations]
    @start_paragraph = annotation.start_paragraph
    @end_paragraph = annotation.end_paragraph
    @start_offset = annotation.start_offset
    @end_offset = annotation.end_offset
    @kind = annotation.kind
    @id = annotation.id
    @content = annotation.content
  end

  def perform
    # Adds data-p-idx to paragraph HTML tag 
    paragraph_node['data-p-idx'] = paragraph_index

    if (paragraph_index != start_paragraph && paragraph_index != end_paragraph) || (paragraph_index == end_paragraph && paragraph_index != start_paragraph && end_offset == paragraph_node.text.length)
      # wrap entire p node in annotation
      paragraph_node.children = annotate_html(paragraph_node.inner_html, handle: false)
      if kind.in? %w{elide replace}
        paragraph_node['data-elided-annotation'] = id
      end
      return
    end

    # This is set for annotations that span multiple paragraphs. After the annotation is applie to each paragraph the character size of the paragraph that is added to this variable so that the next paragraph starts are the right spot. 
    paragraph_offset = 0
    noninitial = paragraph_index != start_paragraph

    paragraph_node.traverse do |node|
      next unless node.text?

      if noninitial
        if middle_paragraph?(node, paragraph_offset)
          wrap_middle_paragraph(node)
        else
          wrap_last_paragraph(node, paragraph_offset)
          break
        end
      else
        if paragraph_offset_ready?(node, paragraph_offset)
          if only_paragraph? && partial_paragraph?(node, paragraph_offset)
            selected_text = annotate_html(node.text[start_offset - paragraph_offset...end_offset - paragraph_offset])
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{selected_text}#{node.text[end_offset - paragraph_offset..-1]}"
            break
          else
            noninitial = true
            selected_text = annotate_html(node.text[start_offset - paragraph_offset..-1])
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{selected_text}"
          end
        end
      end
      paragraph_offset += node.text.length
    end
  end

  private

  def annotate_html(selected_text, handle: true)
    component = {'elide' => 'elision', 'replace' => 'replacement'}[kind] || kind
    "<#{component}-annotation :annotation-id='#{id}' :has-handle='#{handle}'>#{selected_text}</#{component}-annotation>"
  end

  def middle_paragraph?(node, paragraph_offset)
    paragraph_index != end_paragraph || end_offset > paragraph_offset + node.text.length
  end

  def wrap_middle_paragraph(node)
    node.replace annotate_html(node.text, handle: false)
  end

  # This is the last paragraph, apply the annotation to the remaining characters.  
  def wrap_last_paragraph(node, paragraph_offset)
    selected_text = annotate_html(node.text[0...end_offset - paragraph_offset], handle: false)
    node.replace "#{node.text[0...0]}#{selected_text}#{node.text[end_offset - paragraph_offset..-1]}"
  end

  # If the annotation doesn't start at the first character, loop through and add to the paragraph_offset so that you can start at the right place.
  def paragraph_offset_ready?(node, paragraph_offset)
    paragraph_offset + node.text.length >= start_offset
  end

  def only_paragraph?
    paragraph_index == end_paragraph
  end

  def partial_paragraph?(node, paragraph_offset)
    paragraph_offset + node.text.length >= end_offset
  end
end
