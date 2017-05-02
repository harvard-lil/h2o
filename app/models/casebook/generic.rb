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

class Casebook::Generic < ApplicationRecord
  self.table_name = :casebooks

  validates_format_of :slug, with: /\A[a-z\-]*\z/, if: :slug?

  belongs_to :copy_of, class_name: 'Casebook::Generic', inverse_of: :copies, optional: true

  scope :owned, -> {where casebook_collaborators: {role: 'owner'}}
  scope :unmodified, -> {where 'casebooks.created_at = casebooks.updated_at'}

  def slug
    super || self.title.parameterize
  end

  def reflow_contents
    reflow_tree tree, ordinals
  end

  def reflow_tree tree, prefix = []
    ord_index = ordinals.length
    ord = 1
    tree.each do |element|
      if element.is_a? Enumerable
        reflow_tree element, ord == 1 ? prefix : prefix + [ord-1]
      else
        element.update_column :ordinals, prefix + [ord]
        ord += 1
      end
    end
  end

  # Transform a flat sorted array of casebooks into an array tree
  # [1, 1.1, 1.1.1, 1.2, 2, 2.1, 2.1.1] => [1, [1.1, [1.1.1], 1.2], 2, [2.1, [2.1.1]]]
  def tree
    tables = []
    table = []
    n_ords = ordinals.length + 1
    contents.each do |casebook|
      if casebook.ordinals.length > n_ords
        tables.push table.push(table = [])
      elsif casebook.ordinals.length < n_ords
        table = tables.pop until tables.length < casebook.ordinals.length
      end
      n_ords = casebook.ordinals.length
      table.push casebook
    end
    tables.first || table
  end

  private

  def self.discriminate_class_for_record(record)
    if record['root_id'].nil?
      Casebook::Book
    elsif record['material_id'].nil?
      Casebook::Section
    else
      Casebook::Resource
    end
  end
end
