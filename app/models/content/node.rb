class Content::Node < ApplicationRecord
  validates_format_of :slug, with: /\A[a-z\-]*\z/, if: :slug?

  belongs_to :copy_of, class_name: 'Content::Node', inverse_of: :copies, optional: true
  has_many :copies, class_name: 'Content::Node', inverse_of: :copy_of, foreign_key: :copy_of_id, dependent: :nullify
  has_many :unpublished_revisions, dependent: :destroy

  scope :published, -> {where public: true}
  scope :owned, -> {where content_collaborators: {role: 'owner'}}
  scope :followed, -> {where content_collaborators: {role: 'followed'}}
  scope :unmodified, -> {where 'content_nodes.created_at = content_nodes.updated_at'}

  def slug
    super || self.title.parameterize
  end

  def create_revisions(content_params)
    #Creates a revision for every field. Could check for changes but there are ever
    #only 3 fields.
    if self.copy_of.present?
      content_params.each do |field, value|
        previous_revisions = unpublished_revisions.where(field: field)

        if previous_revisions.present?
          previous_revisions.destroy_all
        end
        
        unpublished_revisions.create(field: field, value: value, node_id: self.id, casebook_id: casebook_id_for_revision, node_parent_id: self.copy_of_id)
      end
    end
  end

  def formatted_headnote
    unless self.headnote.blank?
      headnote_html = Nokogiri::HTML self.headnote {|config| config.strict.noblanks}
      headnote_html.to_html.html_safe
    end
  end

  def has_collaborator?(user_id)
    collaborators.pluck(:user_id).include?(user_id)
  end

  private

  def casebook_id_for_revision
    #if it's a resource return the casebook_id
    #if it's the actual casebook, return it's own id
    self.casebook_id || self.id
  end

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
