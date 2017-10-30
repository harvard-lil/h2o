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

# Abstract class for anything that can be a node in a table of contents:
# Casebooks, Sections, Resources all inherit from this
# - is a row in content_nodes table
# - can be a copy of another Node
# - has a title, subtitle, headnote, public status
class Content::Node < ApplicationRecord
  validates_format_of :slug, with: /\A[a-z\-]*\z/, if: :slug?

  belongs_to :copy_of, class_name: 'Content::Node', inverse_of: :copies, optional: true
  has_many :copies, class_name: 'Content::Node', inverse_of: :copy_of, foreign_key: :copy_of_id, dependent: :nullify
  has_ancestry :orphan_strategy => :adopt

  scope :published, -> {where public: true}
  scope :owned, -> {where content_collaborators: {role: 'owner'}}
  scope :followed, -> {where content_collaborators: {role: 'followed'}}
  scope :unmodified, -> {where 'content_nodes.created_at = content_nodes.updated_at'}

  def slug
    super || self.title.parameterize
  end

  private

  # Resolve the correct subclass for this record.
  # This implements single-table inheritance for all Content::Node subclasses.
  def self.discriminate_class_for_record(record)
    if record['casebook_id'].nil?
      Content::Casebook # Casebooks are nodes which do not belong to a casebook.
    elsif record['resource_id'].nil?
      Content::Section # Sections are Child nodes which do not have an associated material resource.
    else
      Content::Resource # Resources are Child nodes which have associated material.
    end
  end
end
