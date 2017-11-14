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

# Abstract class for anything that is a child node in a table of contents:
# Sections, Resources inherit from this
# - belongs to a root Casebook
# - has ordinals which are not empty
# - can be relocated in the table of contents, pushing siblings aside
# - inherits the collaborators of its Casebook
class Content::Child < Content::Node
  default_scope {where.not(casebook_id: nil)}

  validates_length_of :ordinals, minimum: 1
  validates_uniqueness_of :ordinals, scope: :casebook_id, if: :casebook_id?, message: 'are not unique'

  before_validation :move_siblings, if: :ordinals_changed?
  # after_update :move_children, if: :saved_change_to_ordinals?
  # after_save :reflow_casebook, if: :saved_change_to_ordinals?
  after_destroy :reflow_casebook

  belongs_to :casebook, class_name: 'Content::Casebook', inverse_of: :contents, required: true, touch: true

  has_many :collaborators, class_name: 'Content::Collaborator', primary_key: :casebook_id, foreign_key: :content_id
  include Content::Concerns::HasCollaborators

  def section
    if ordinals.length == 1
      casebook
    else
      casebook.contents.where(['ordinals = ARRAY[?]', ordinals[0..-2]])
      .first
    end
  end

  def ordinal_string
    ordinals.join I18n.t('content.show.ordinals-separator', '.')
  end

  # has a user-readable id consisting of ordinals, e.g.:
  # 2.1.3-further-considerations
  def to_param
    "#{ordinals.join '.'}-#{slug}"
  end

  private

  # moves siblings and niblings before validation
  def move_siblings
    ord_idx = ordinals.length
    if ord_idx > 1
      casebook.contents
      .where(['ordinals[1:?] = ARRAY[?]::integer[]', ordinals.length-1, ordinals[0...-1]]) # siblings
    else
      casebook.contents # or all contents
    end
    .where(['ordinals[?] >= ?', ord_idx, ordinals.last]) # after us
    .update_all ['ordinals[?] = ordinals[?] + 1', ord_idx, ord_idx]
    logger.debug casebook.contents.reload.map &:ordinal_string
  end

  # if the Node at a has been reordered to before b, determine where a's children are now
  def reorder_index a, b
    if a.length < b.length
      if a.last <= b[a.length-1]
        a.length - 1
      end
    elsif a.length > b.length
      nil
    else
      a.zip(b).find_index {|ab| ab[0] < (ab[1] || 0)}
    end
  end

  # moves children and descendants after update
  def move_children
    adjusted_prior_ordinals = ordinals_before_last_save
    if (idx = reorder_index ordinals, adjusted_prior_ordinals)
      adjusted_prior_ordinals[idx] += 1# children have been incremented
    else
      ordinals_before_last_save # children are the same
    end
    casebook.contents
    .where(['ordinals[1:?] = ARRAY[?]', adjusted_prior_ordinals.length, adjusted_prior_ordinals]) # our descendants
    .update_all ['ordinals = ARRAY[?] || ordinals[?:array_length(ordinals, 1)]', ordinals, adjusted_prior_ordinals.length + 1]
    logger.debug casebook.contents.reload.map &:ordinal_string
  end

  def reflow_casebook
    casebook.reflow_contents
  end
end
