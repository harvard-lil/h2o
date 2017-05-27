# == Schema Information
#
# Table name: content_annotations
#
#  id           :integer          not null, primary key
#  resource_id  :integer          not null
#  start_p      :integer          not null
#  end_p        :integer
#  start_offset :integer          not null
#  end_offset   :integer          not null
#  kind         :string           not null
#  content      :text
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class Content::Annotation < ApplicationRecord
  KINDS = %w{elide replace link highlight note}
  belongs_to :resource, class_name: 'Content::Resource', inverse_of: :annotations, required: true

  validates_inclusion_of :kind, in: KINDS, message: "must be one of: #{KINDS.join ', '}"

  after_create :copy_resource_annotations, if: -> {resource.is_alias}

  def copy_resource_annotations
    return unless resource.is_alias

    resource.update_attributes is_alias: false
    resource.copy_of.annotations.map(&:dup).each do |annotation|
      annotation.update_attributes resource: resource
    end
  end

  def apply_to_node p_node, p_idx
    if p_idx != start_p && p_idx != end_p
      # wrap entire p node in annotation
      p_node.children = annotate_html(p_node.inner_html, handle: false)
      return
    end

    node_offset = 0
    annotating = p_idx != start_p

    # wrap individual text nodes covering the range
    p_node.traverse do |node|
      next unless node.text?

      if annotating
        if p_idx != end_p || end_offset > node_offset + node.text.length
          # wrap this entire node
          node.replace annotate_html(node.text, handle: false)
        else
          # wrap to end_offset
          node.replace "#{node.text[0...0]}#{annotate_html(node.text[0...end_offset - node_offset], handle: false)}#{node.text[end_offset - node_offset...-1]}"
          break # done annotating
        end
      else
        if node_offset + node.text.length >= start_offset
          if p_idx == end_p && node_offset + node.text.length >= end_offset
            # wrap within this node
            inner = annotate_html node.text[start_offset - node_offset...end_offset - node_offset]
            node.replace "#{node.text[0...start_offset - node_offset]}<span data-annotation-id='#{id}' class='annotation-handle #{kind}'><span class='annotation-button'>Annotate</span></span>#{inner}#{node.text[end_offset - node_offset..-1]}"
            break # done annotating
          else
            # wrap the rest of this node from start_offset and continue annotating
            annotating = true
            inner = annotate_html node.text[start_offset - node_offset..-1]
            node.replace "#{node.text[0...start_offset - node_offset]}<span data-annotation-id='#{id}' class='annotation-handle #{kind}'><span class='annotation-button'>Annotate</span></span>#{inner}"
          end
        else
          # don't start annotating yet
        end
      end
      node_offset += node.text.length
    end

  end

  def annotate_html inner, handle: true
    case kind
    when 'elide' then
      "#{handle ? "<span class='annotate elide'></span>" : ''}<span class='annotate elided'>#{inner}</span>"
    when 'replace' then
      "#{handle ? "<span class='annotate replacement'>#{content}</span>" : ''}<span class='annotate replaced'>#{inner}</span>"
    when 'highlight' then
      "<span class='annotate highlighted'>#{inner}</span>"
    when 'link' then
      "<a href='#{content}' class='annotate link'>#{inner}</a>"
    when 'note' then
      "<span class='annotate highlight'>#{inner}#{handle ? "<span class='annotate note-icon'>[see note]</span>" : ''}</span>"
    else
    end
  end
end
