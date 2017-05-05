# == Schema Information
#
# Table name: casebooks
#
#  id            :integer          not null, primary key
#  title         :string
#  slug          :string
#  subtitle      :string
#  headnote      :text
#  public        :boolean          default(TRUE), not null
#  book_id       :integer
#  ordinals      :integer          default([]), not null, is an Array
#  copy_of_id    :integer
#  is_alias      :boolean
#  resource_type :string
#  resource_id   :integer
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

  private

  # find the appropriate Casebook subclass for this record.
  def self.discriminate_class_for_record(record)
    if record['book_id'].nil?
      Casebook::Book
    elsif record['resource_id'].nil?
      Casebook::Section
    else
      Casebook::Resource
    end
  end
end
