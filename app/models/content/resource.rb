class Content::Resource < Content::Child
  default_scope {where.not(resource_id: nil)}

  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, required: true
  has_many :annotations, class_name: 'Content::Annotation', dependent: :destroy

  accepts_nested_attributes_for :resource

  def can_delete?
    true
  end

  def paragraph_nodes
    HTMLHelpers.process_p_nodes(
      Nokogiri::HTML(resource.content) {|config| config.strict.noblanks})
  end

  def annotated_paragraphs(editable: false, exporting: false, include_annotations: include_annotations)
    nodes = paragraph_nodes
    #export_footnote_index determines how many astericks are next to a link or note annotation in the exported version of a resource
    export_footnote_index = 0

    nodes.each_with_index do |p_node, p_idx|
      p_node['data-p-idx'] = p_idx
    end

    annotations.all.sort_by{|annotation| annotation.start_paragraph}.each_with_index do |annotation|
      if annotation.kind.in? %w(note link)
        export_footnote_index += 1
      end

      if nodes[annotation.start_paragraph..annotation.end_paragraph].nil?
        Notifier.missing_annotations(self.collaborators.pluck(:email_address, :attribution), self, annotation)
      else
        nodes[annotation.start_paragraph..annotation.end_paragraph].each_with_index do |paragraph_node, paragraph_index|
          ApplyAnnotationToParagraphs.perform({annotation: annotation, paragraph_node: paragraph_node, paragraph_index: paragraph_index + annotation.start_paragraph, export_footnote_index: export_footnote_index, editable: editable, exporting: exporting, include_annotations: include_annotations})
        end
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

    annotations.all.sort_by{|annotation| annotation.start_paragraph}.each_with_index do |annotation, index|
      if annotation.kind.in? %w(note link)
        idx += 1
        footnote_annotations += "#{("*" * (idx)) + annotation.content} "
      end
    end

    footnote_annotations
  end

  def has_elisions?
    annotations.where(kind: ["elide", "replace"]).any?
  end
end
