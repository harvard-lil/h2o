class Content::Resource < Content::Child
  default_scope {where.not(resource_id: nil)}

  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, required: true
  has_many :annotations, class_name: 'Content::Annotation', dependent: :destroy

  accepts_nested_attributes_for :resource

  def can_delete?
    true
  end

  def paragraph_nodes
    html = Nokogiri::HTML resource.content {|config| config.strict.noblanks}
    nodes = preprocess_nodes html

    nodes.each do |node|
      if ! node.nil? && node.children.empty?
        nodes.delete(node)
      end
    end

    nodes
  end

  def preprocess_nodes html
    # strip comments
    html.xpath('//comment()').remove

    # unwrap div tags
    html.xpath('//div')
      .each { |div| div.replace div.children }

    # rewrap empty lists
    html.xpath('//body/ul[not(*[li])]')
      .each { |list| list.replace "<p>#{list.inner_html}</p>" }

    # wrap bare inline tags
    html.xpath('//body/*[not(self::p|self::center|self::blockquote|self::article)]')
      .each { |inline_element| inline_element.replace "<p>#{inline_element.to_html}</p>" }

    html.xpath "//body/node()[not(self::text()) and not(self::text()[1])]"
  end

  def annotated_paragraphs(editable: false, exporting: false)
    nodes = paragraph_nodes
    export_p_idx = 0

    nodes.each_with_index do |p_node, p_idx|
      p_node['data-p-idx'] = p_idx
    end

    annotations.all.sort_by{|annotation| annotation.start_p}.each_with_index do |annotation|
      if annotation.kind.in? %w(note link)
        export_p_idx += 1
      end

      nodes[annotation.start_p..annotation.end_p].each_with_index do |p_node, p_idx|
        annotation.apply_to_node(p_node, p_idx + annotation.start_p, export_p_idx, editable: editable, exporting: exporting)
      end
    end

    nodes
  end

  def title
    super || resource.title
  end

  def footnote_annotations
    footnote_annotations = ""
    idx = 0

    annotations.all.sort_by{|annotation| annotation.start_p}.each_with_index do |annotation, index|
      if annotation.kind.in? %w(note link)
        idx += 1
        footnote_annotations += "#{("*" * (idx)) + annotation.content} "
      end
    end

    footnote_annotations
  end
end
