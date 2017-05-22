# == Schema Information
#
# Table name: content_nodes
#
#  id            :integer          not null, primary key
#  title         :string
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  casebook_id   :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  resource_type :string
#  resource_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

# Concrete class for a Resource, a leaf node in a table of contents.
# - is a Child
# - cannot have Children
# - contains a reference to a single material resource, i.e. a Case, TextBlock, or Link
class Content::Resource < Content::Child
  default_scope {where.not(resource_id: nil)}

  belongs_to :resource, polymorphic: true, inverse_of: :casebooks, required: true
  has_many :annotations, class_name: 'Content::Annotation', dependent: :destroy

  def can_delete?
    true
  end

  def paragraph_nodes
    html = Nokogiri::HTML resource.content {|config| config.noblanks}
    html.xpath('//p')
  end

  def annotated_paragraphs
    nodes = paragraph_nodes

    annotations.all.each_with_index do |annotation|
      nodes[annotation.start_p..annotation.end_p].each_with_index do |p_node, p_idx|
        annotation.apply_to_node p_node, p_idx + annotation.start_p
      end
    end

    nodes.map &:inner_html
  end

  def annotations
    if is_alias?
      copy_of.annotations
    else
      super
    end
  end

  def title
    super || resource.title
  end
end
