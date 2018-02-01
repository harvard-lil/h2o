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
  has_many :unpublished_revisions

  scope :published, -> {where public: true}
  scope :owned, -> {where content_collaborators: {role: 'owner'}}
  scope :followed, -> {where content_collaborators: {role: 'followed'}}
  scope :unmodified, -> {where 'content_nodes.created_at = content_nodes.updated_at'}

  def slug
    super || self.title.parameterize
  end

  def create_revisions(content_params)
    content_params.each do |field|
      unless field == "id"
        previous_revisions = unpublished_revisions.where(field: field)
        if previous_revisions.present?
          previous_revisions.destroy_all
        end
        unpublished_revisions.create(field: field, value: content_params[field])
      end
    end
  end

  def formatted_headnote
    Nokogiri::HTML self.headnote {|config| config.strict.noblanks}
  end

  def merge_revisions(original)
    draft_casebook = self
    original_casebook = original

    merge_shallow_revisions(original)
    # merges initial casebook object
    # loop through and merge all resources
    # new_resources = self.resources.where(created_at > self.created_at) 
    # modified_resources = self.resources.where(created_at < self.created_at).where(updated_at > self.updated_at)
    # find_changed_values(modified_resources)
    #### Annotations:
    #### resource_ids = self.resources.pluck(:id)
    #### Content::Annotation.where(resource_id: resource_ids).where(created_at > self.created_at)
    #### ^ Copy these over
    #### Probably do need to look for revised ones 
    # loop through and merge in collaborators
    # return original object
  end

  def merge_shallow_revisions(original)

  end

  def merge_resources(resource)
    # https://stackoverflow.com/questions/11853491/merging-two-ruby-objects

    parent_resource = Content::Resource.find(resource.copy_of_id)

    resource <=> parent_resource

    ## return resource or parent resource? 
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
