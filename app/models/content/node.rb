# == Schema Information
#
# Table name: content_nodes
#
# t.string "title"
# t.string "slug"
# t.string "subtitle"
# t.text "headnote"
# t.boolean "public", default: true, null: false
# t.bigint "casebook_id"
# t.integer "ordinals", default: [], null: false, array: true
# t.bigint "copy_of_id"
# t.boolean "is_alias"
# t.string "resource_type"
# t.bigint "resource_id"
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false
# t.string "ancestry"
# t.bigint "playlist_id"
# t.bigint "root_user_id"
# t.boolean "draft_mode_of_published_casebook"
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
        unpublished_revisions.create(field: field, value: content_params[field], casebook_id: (self.casebook_id || self.id), node_parent_id: self.copy_of_id)
      end
    end
  end

  def formatted_headnote
    Nokogiri::HTML self.headnote {|config| config.strict.noblanks}
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
