# == Schema Information
#
# Table name: content_annotations
#
# t.bigint "resource_id", null: false
# t.integer "start_p", null: false
# t.integer "end_p"
# t.integer "start_offset", null: false
# t.integer "end_offset", null: false
# t.string "kind", null: false
# t.text "content"
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false
# t.bigint "copy_of_id"
#

class Content::Annotation < ApplicationRecord
  KINDS = %w{elide replace link highlight note}
  belongs_to :resource, class_name: 'Content::Resource', inverse_of: :annotations, required: true
  has_one :unpublished_revision

  validates_inclusion_of :kind, in: KINDS, message: "must be one of: #{KINDS.join ', '}"


  def apply_to_node p_node, p_idx, editable: false
    p_node['data-p-idx'] = p_idx

    if (p_idx != start_p && p_idx != end_p) || (p_idx == end_p && p_idx != start_p && end_offset == p_node.text.length)
      # wrap entire p node in annotation
      p_node.children = annotate_html(p_node.inner_html, handle: false)
      if kind.in? %w{elide replace}
        p_node['data-elided-annotation'] = id
      end
      return
    end

    node_offset = 0
    annotating = p_idx != start_p

    # wrap individual text nodes covering the range
    p_node.traverse do |node|
      next unless node.text?

      if node.parent['class'].in? ['annotation-button', 'annotate note-icon', 'note-content', 'text']
        next
      end

      if annotating
        if p_idx != end_p || end_offset > node_offset + node.text.length
          # wrap this entire node
          node.replace annotate_html(node.text, handle: false)
        else
          # wrap to end_offset
          node.replace "#{node.text[0...0]}#{annotate_html(node.text[0...end_offset - node_offset], handle: false, final: true)}#{node.text[end_offset - node_offset...-1]}"
          break # done annotating
        end
      else
        if node_offset + node.text.length >= start_offset
          handle_html = if editable
            "<span data-annotation-id='#{id}' data-annotation-type='#{kind}' class='annotation-handle #{kind}'><span class='annotation-button'>Annotate</span></span>"
          else
            ''
          end
          if p_idx == end_p && node_offset + node.text.length >= end_offset
            # wrap within this node
            inner = annotate_html node.text[start_offset - node_offset...end_offset - node_offset], final: true
            node.replace "#{node.text[0...start_offset - node_offset]}#{handle_html}#{inner}#{node.text[end_offset - node_offset..-1]}"
            break # done annotating
          else
            # wrap the rest of this node from start_offset and continue annotating
            annotating = true
            inner = annotate_html node.text[start_offset - node_offset..-1]
            node.replace "#{node.text[0...start_offset - node_offset]}#{handle_html}#{inner}"
          end
        else
          # don't start annotating yet
        end
      end
      node_offset += node.text.length
    end
  end

  def copy_of
    resource.copy_of.annotations.where(start_p: self.start_p, end_p: self.end_p, 
          start_offset: self.start_offset, end_offset: self.end_offset, kind: self.kind).first
  end

  def exists_in_published_casebook?
    resource.casebook.draft_mode_of_published_casebook && copy_of.present?
  end

  private

  def annotate_html inner, handle: true, final: false
    case kind
    when 'elide' then
      "#{handle ? "<span class='annotate elide' data-annotation-id='#{id}'></span>" : ''}<span class='annotate elided' data-annotation-id='#{id}'>#{inner}</span>"
    when 'replace' then
      "#{handle ? "<span role='button' tabindex='0' class='annotate replacement' data-annotation-id='#{id}'><span class='text' data-annotation-id='#{id}'>#{escaped_content}</span></span>" : ''}<span class='annotate replaced' data-annotation-id='#{id}'>#{inner}</span>"
    when 'highlight' then
      "<span class='annotate highlighted' data-annotation-id='#{id}'>#{inner}</span>"
    when 'link' then
      "<a href='#{escaped_content}' target='_blank' class='annotate link' data-annotation-id='#{id}'>#{inner}</a>"
    when 'note' then
      "<span class='annotate highlighted' data-annotation-id='#{id}'>#{inner}#{final ? "<span class='annotate note-icon' data-annotation-id='#{id}'>[see note]</span>" : ''}</span>#{final ? "<span class='annotate note-content-wrapper' data-annotation-id='#{id}'><span class='note-content'>#{escaped_content}</span></span>" : ''}"
    else
    end
  end

  def escaped_content
    ApplicationController.helpers.send(:html_escape, content)
  end
end
