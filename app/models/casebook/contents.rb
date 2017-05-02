# == Schema Information
#
# Table name: casebooks
#
#  id            :integer          not null, primary key
#  title         :string           default("Untitled casebook"), not null
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  root_id       :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  material_type :string
#  material_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class Casebook::Contents < Casebook::Generic
  default_scope {where.not(root_id: nil)}

  validates_length_of :ordinals, minimum: 1
  validates_uniqueness_of :ordinals, scope: :root_id, if: :root_id?, message: 'are not unique'

  before_validation :move_siblings, if: :ordinals_changed?
  after_update :move_children, if: :saved_change_to_ordinals?
  after_save :reflow_book, if: :saved_change_to_ordinals?
  after_destroy :reflow_book

  belongs_to :root, class_name: 'Casebook::Book', inverse_of: :contents, required: true, touch: true

  has_many :collaborators, class_name: 'Casebook::Collaborator', primary_key: :root_id, foreign_key: :casebook_id
  include Casebook::Concerns::Collaborators

  def section
    if ordinals.length == 1
      root
    else
      root.contents.where(['ordinals = ARRAY[?]', ordinals[0..-2]])
      .first
    end
  end

  def ordinal_string
    ordinals.join I18n.t('casebooks.show.ordinals-separator', '.')
  end

  def to_param
    "#{ordinals.join '.'}-#{slug}"
  end

  private

  # moves siblings and niblings before validation
  def move_siblings
    ord_idx = ordinals.length
    logger.debug root.contents.map &:ordinal_string
    if ord_idx > 1
      root.contents
      .where(['ordinals[1:?] = ARRAY[?]::integer[]', ordinals.length-1, ordinals[0...-1]]) # siblings
    else
      root.contents # or all contents
    end
    .where(['ordinals[?] >= ?', ord_idx, ordinals.last]) # after us
    .update_all ['ordinals[?] = ordinals[?] + 1', ord_idx, ord_idx]
    logger.debug root.contents.reload.map &:ordinal_string
  end

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
    logger.debug "prior: #{adjusted_prior_ordinals} current: #{ordinals} before: #{reorder_index ordinals, adjusted_prior_ordinals}"
    logger.debug root.contents.reload.map &:ordinal_string
    if (idx = reorder_index ordinals, adjusted_prior_ordinals)
      adjusted_prior_ordinals[idx] += 1# children have been incremented
    else
      ordinals_before_last_save # children are the same
    end
    root.contents
    .where(['ordinals[1:?] = ARRAY[?]', adjusted_prior_ordinals.length, adjusted_prior_ordinals]) # our descendants
    .update_all ['ordinals = ARRAY[?] || ordinals[?:array_length(ordinals, 1)]', ordinals, adjusted_prior_ordinals.length + 1]
    logger.debug root.contents.reload.map &:ordinal_string
  end

  def reflow_book
    root.reflow_contents
  end
end
