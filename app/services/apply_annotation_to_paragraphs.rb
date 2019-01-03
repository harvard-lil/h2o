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

      if node.parent['data-exclude-from-offset-calcs']&.downcase == "true"
        next
      end

      if noninitial
        if middle_paragraph?(node, paragraph_offset)
          wrap_middle_paragraph(node)
        else
          wrap_last_paragraph(node, paragraph_offset)
          break
        end
      else
        if paragraph_offset_ready?(node, paragraph_offset)
          annotation_button = get_annotation_button_and_note_wrapper

          if only_paragraph? && partial_paragraph?(node, paragraph_offset)
            selected_text = annotate_html(node.text[start_offset - paragraph_offset...end_offset - paragraph_offset])
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{annotation_button}#{selected_text}#{node.text[end_offset - paragraph_offset..-1]}"
            break
          else
            noninitial = true
            selected_text = annotate_html(node.text[start_offset - paragraph_offset..-1])
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{annotation_button}#{selected_text}"
          end
        end
      end
      paragraph_offset += node.text.length
    end
  end

  private

  # The edit icon that shows up next to an annotation when in draft mode.
  def get_annotation_button_and_note_wrapper
    if kind == 'note'
      if editable
        "<span class='annotate note-content-wrapper' data-annotation-id='#{id}'><span class='note-icon' data-annotation-id='#{id}' data-exclude-from-offset-calcs='true'><i class='fas fa-paperclip'></i></span><span class='note-content' data-exclude-from-offset-calcs='true'>#{escaped_content}</span></span>"
      # Show notes only when not exporting, or exporting with annotations
      elsif !exporting || (exporting && include_annotations)
        "<span class='annotate note-content-wrapper' data-annotation-id='#{id}'><span class='note-icon' data-annotation-id='#{id}' data-exclude-from-offset-calcs='true'><i class='fas fa-paperclip'></i></span><span class='note-content' data-exclude-from-offset-calcs='true'>#{escaped_content}</span></span>"
      end
    else
      ""
    end
  end

  # NB: the export to docx code is tightly coupled with this markup. Test thoroughly if altering.
  def annotate_html_old(selected_text, handle: true)
    case kind
    when 'elide' then
      "#{handle ? "<span role='button' tabindex='0' class='annotate elide' data-annotation-id='#{id}' aria-label='elided text' aria-expanded='false'></span>" : ''}" +
      "<span class='annotate elided' data-annotation-id='#{id}'>#{selected_text}</span>"
    when 'replace' then
      "#{handle ? "<span role='button' tabindex='0' aria-expanded='false' class='annotate replacement' data-annotation-id='#{id}'><span class='text' data-annotation-id='#{id}' data-exclude-from-offset-calcs='true'>#{escaped_content}</span></span>" : ''}<span class='annotate replaced' data-annotation-id='#{id}'>#{selected_text}</span>"
    when 'highlight' then
      "<span tabindex='-1' class='annotate highlighted' data-annotation-id='#{id}'>#{selected_text}</span>"
    when 'link' then
      if exporting && paragraph_index == end_paragraph && include_annotations
        "<a href='#{escaped_content}' target='_blank' class='annotate link' data-annotation-id='#{id}'>#{selected_text}</a>#{'*' * export_footnote_index}"
      else
        "<a href='#{escaped_content}' target='_blank' class='annotate link' data-annotation-id='#{id}'>#{selected_text}</a>"
      end
    when 'note' then
      if exporting && paragraph_index == end_paragraph && include_annotations
        "<span tabindex='-1' class='annotate note' data-annotation-id='#{id}'>#{selected_text}</span>#{'*' * export_footnote_index}"
      else
        "<span tabindex='-1' class='annotate note' data-annotation-id='#{id}'>#{selected_text}</span>"
      end
    end
  end

  def annotate_html(selected_text, handle: true)
    component = {'elide' => 'elision', 'replace' => 'replacement'}[kind] || kind
    "<#{component}-annotation :annotation-id='#{id}' :has-handle='#{handle}'>#{selected_text}</#{component}-annotation>"
  end

  def escaped_content
    ApplicationController.helpers.send(:html_escape, content)
  end

  # If it's a multi-paragraph annotation and this paragraph is in the middle, annotate the entire paragraph
  def full_paragraph_node_annotated?
    (!first_paragraph? && !last_paragraph?) || (paragraph_index == end_paragraph && paragraph_index != start_paragraph && end_offset == paragraph_node.text.length)
  end

  def first_paragraph?
    paragraph_index == start_paragraph
  end

  def last_paragraph?
    paragraph_index == end_paragraph
  end

  def wrap_paragraph_node
    paragraph_node.children = annotate_html(paragraph_node.inner_html, handle: false)
    if kind.in? %w{elide replace}
      paragraph_node['data-elided-annotation'] = id
    end
    return
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
