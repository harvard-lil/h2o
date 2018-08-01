class ApplyAnnotationToParagraphs
  attr_accessor :annotation, :paragraph_node, :paragraph_index, :export_footnote_index, :editable, :exporting, :start_paragraph, :end_paragraph, :start_offset, :end_offset, :kind, :id, :content

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
    @start_paragraph = annotation.start_paragraph
    @end_paragraph = annotation.end_paragraph
    @start_offset = annotation.start_offset
    @end_offset = annotation.end_offset
    @kind = annotation.kind
    @id = annotation.id
    @content = annotation.content
  end

  def perform
    paragraph_offset = 0
    paragraph_node['data-p-idx'] = paragraph_index

    if full_paragraph_node_annotated?
      wrap_paragraph_node 
    end

    paragraph_node.traverse do |node|
      if invalid_node?(node)
        next
      end

      if first_paragraph?
        if paragraph_offset_ready?(node, paragraph_offset)
          annotation_button = get_edit_annotation_button

          if only_paragraph? && partial_paragraph?(node, paragraph_offset)
            selected_text = annotate_html(node.text[start_offset - paragraph_offset...end_offset - paragraph_offset], final: true)
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{annotation_button}#{selected_text}#{node.text[end_offset - paragraph_offset..-1]}"
            break
          else
            annotating = true
            selected_text = annotate_html(node.text[start_offset - paragraph_offset..-1])
            node.replace "#{node.text[0...start_offset - paragraph_offset]}#{annotation_button}#{selected_text}"
          end
        end
      else 
        if middle_paragraph?(node, paragraph_offset)
          wrap_single_node(node)
        else
          wrap_to_end_offset(node, paragraph_offset)
          break
        end
      end
      paragraph_offset += node.text.length
    end
  end

  private

  def get_edit_annotation_button
    if editable
      if kind == 'note'
      "<span data-annotation-id='#{id}' data-annotation-type='#{kind}' class='annotation-handle #{kind}'><span class='annotation-button'>Annotate</span></span><span class='annotate note-content-wrapper' data-annotation-id='#{id}'><span class='note-icon' data-annotation-id='#{id}'><i class='fas fa-paperclip'></i></span><span class='note-content'>#{escaped_content}</span></span>"
      else
      "<span data-annotation-id='#{id}' data-annotation-type='#{kind}' class='annotation-handle #{kind}'><span class='annotation-button'>Annotate</span></span>"
      end
    else
      ""
    end
  end

  # NB: the export to docx code is tightly coupled with this markup. Test thoroughly if altering.
  def annotate_html(selected_text, handle: true, final: false)
    case kind
    when 'elide' then
      "#{handle ? "<span role='button' tabindex='0' class='annotate elide' data-annotation-id='#{id}' aria-label='elided text' aria-expanded='false'></span>" : ''}" +
      "<span class='annotate elided' data-annotation-id='#{id}'>#{selected_text}</span>"
    when 'replace' then
      "#{handle ? "<span role='button' tabindex='0' aria-expanded='false' class='annotate replacement' data-annotation-id='#{id}'><span class='text' data-annotation-id='#{id}'>#{escaped_content}</span></span>" : ''}<span class='annotate replaced' data-annotation-id='#{id}'>#{selected_text}</span>"
    when 'highlight' then
      "<span tabindex='-1' class='annotate highlighted' data-annotation-id='#{id}'>#{selected_text}</span>"
    when 'link' then
      if exporting
        "<a href='#{escaped_content}' target='_blank' class='annotate link' data-annotation-id='#{id}'>#{selected_text}#{'*' * export_footnote_index}</a>"
      else
        "<a href='#{escaped_content}' target='_blank' class='annotate link' data-annotation-id='#{id}'>#{selected_text}</a>"
      end
    when 'note' then
      if exporting
        "<span tabindex='-1' class='annotate note' data-annotation-id='#{id}'>#{selected_text}#{'*' * export_footnote_index}</span>"
      else
        "<span tabindex='-1' class='annotate note' data-annotation-id='#{id}'>#{selected_text}</span>"
      end
    end
  end

  def escaped_content
    ApplicationController.helpers.send(:html_escape, content)
  end

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

  def invalid_node?(node)
    (node.parent['class'].in? ['annotation-button', 'annotate note-icon', 'note-content', 'text']) || ! node.text?
  end

  def middle_paragraph?(node, paragraph_offset)
    paragraph_index != end_paragraph || end_offset > paragraph_offset + node.text.length
  end

  def wrap_single_node(node)
    node.replace annotate_html(node.text, handle: false)
  end

  def wrap_to_end_offset(node, paragraph_offset)
    node.replace "#{node.text[0...0]}#{annotate_html(node.text[0...end_offset - paragraph_offset], handle: false, final: true)}#{node.text[end_offset - paragraph_offset...-1]}"
  end

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
