
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

  def annotated_paragraphs editable: false
    nodes = paragraph_nodes

    nodes.each_with_index do |p_node, p_idx|
      p_node['data-p-idx'] = p_idx
    end

    annotations.all.each_with_index do |annotation|
      nodes[annotation.start_p..annotation.end_p].each_with_index do |p_node, p_idx|
        annotation.apply_to_node p_node, p_idx + annotation.start_p, editable: editable
      end
    end

    nodes
  end

  # def annotations
  #   if is_alias?
  #     copy_of.annotations # delete all of this because i should run a script to migrate 
  #     # all and then when a new casebook is cloned it will have fresh annotations
  #   else
  #     super
  #   end
  # end

  def title
    super || resource.title
  end
end
