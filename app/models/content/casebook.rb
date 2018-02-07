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
#  has_root_dependency      :boolean
#  resource_type :string
#  resource_id   :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

# Concrete class for a Casebook, the root node of a table of contents.
# - does not belong to a Casebook
# - has ordinals of []
# - can have children
# - can have collaborators of its own
class Content::Casebook < Content::Node
  has_ancestry :orphan_strategy => :adopt

  default_scope {where(casebook_id: nil)}

  validates :casebook_id, presence: false
  validates_length_of :ordinals, is: 0

  has_many :contents, -> {order :ordinals}, class_name: 'Content::Child', inverse_of: :casebook, foreign_key: :casebook_id, dependent: :delete_all
  has_many :collaborators, class_name: 'Content::Collaborator', dependent: :destroy, inverse_of: :content, foreign_key: :content_id

  include Content::Concerns::HasCollaborators
  include Content::Concerns::HasChildren

  after_create :clone_contents, if: -> {copy_of.present?}

  searchable do
    text :title, boost: 3.0
    text :subtitle
    text :headnote

    # text :content do
    #   if self.is_a? Content::Resource
    #     resource.content
    #   end
    # end

    string(:klass, stored: true) { self.class.name }
    string(:display_name, stored: true) { title }
    boolean :public

    integer :owner_ids, stored: true, multiple: true do
      owners.map &:id
    end

    string(:attribution, stored: true) { owners.first.try(:attribution) }
    string(:affiliation, stored: true) { owners.first.try(:affiliation) }
    string(:verified_professor, stored: true) { owners.first.try(:verified_professor) }
  end

  def clone(owner:)
    cloned_casebook = dup

    if self.owner == owner && self.public
      draft_mode_of_published_casebook = true
    end

    cloned_casebook.update(copy_of: self, collaborators:  [Content::Collaborator.new(user: owner, role: 'owner')], public: false, parent: self, draft_mode_of_published_casebook: draft_mode_of_published_casebook )
    cloned_casebook
  end

  def clone_contents
    begin
      connection = ActiveRecord::Base.connection
      columns = self.class.column_names - %w{id casebook_id copy_of_id has_root_dependency}
      query = <<-SQL
        INSERT INTO content_nodes(#{columns.join ', '},
          copy_of_id,
          casebook_id,
          has_root_dependency
        )
        SELECT #{columns.join ', '},
          id,
          #{connection.quote(id)},
          #{connection.quote(true)}
        FROM content_nodes WHERE casebook_id=#{connection.quote(copy_of.id)};
      SQL
      ActiveRecord::Base.connection.execute(query)
    end

    clone_annotations
  end

  def clone_annotations
    self.resources.each do |resource|
      resource.update_attributes has_root_dependency: false
      resource.copy_of.annotations.each do |annotation|
        new_annotation = annotation.dup
        new_annotation.update_attributes(resource: resource, copy_of_id: annotation.id)
      end
    end
  end

  def merge_revisions_into_published_casebook
    published_casebook = self.parent
    revisions = UnpublishedRevision.where(casebook_id: self.id)

    # 1. Merge in unpublished revisions (includes: title, headnote, subtitle, textblock changes (not including annotations) and default changes)
    revisions.where.not(field: "deleted_annotation").each do |revision|
      resource = Content::Node.find(revision.node_parent_id)
      resource.update("#{revision.field}": revision.value)
      revision.destroy
    end

    # 2. Merge in new annotations and updated
    annotations = Content::Annotation.where(casebook_id: self.id).where("updated_at > ?", self.created_at + 1.minute)

    annotations.each do |annotation|
      if annotation.copy_of_id.present?
        Content::Annotation.destroy(annotation.copy_of_id)
      end
      parent_resource = Content::Resource.find(annotation.resource_id).parent
      annotation.update(resource_id: parent_resource.id)
    end


    # 4. Delete deleted annotations
    revisions.where(field: "deleted_annotation").each do |revision|
      Content::Annotation.destroy(revision.value)
    end

    # 5. Add any new content collaborators
    new_collaborators = Content::Collaborator.where(content_id: self.id).where("created_at > ?", self.created_at)

    if new_collaborators.present?
      new_collaborators.each do |collaborator|
        new_collaborator = collaborator.dup
        new_collaborator.update_attributes(content_id: published_casebook.id)
      end
    end

    # 7. Delete draft casebook
    self.destroy138G
  end

  def display_name
    title
  end

  def owner
    owners.first
  end

  def owner= user
    collaborators << Content::Collaborator.new(user: user, role: 'owner')
  end

  def root_owner
    if root_user_id.present?
      User.find(root_user_id)
    elsif self.ancestry.present?
      User.joins(:content_collaborators).where(content_collaborators: { ccontent_id: self.root.id, role: 'owner' }).first ## make sure this returns root
    end
  end

  def title
    super || I18n.t('content.untitled-casebook', id: id)
  end

  def to_param
    "#{id}-#{slug}"
  end

  def destroy
    if self.descendants.present?
     raise "Cannot delete a casebook with active descendants"
    else
      super
    end
  end
end
