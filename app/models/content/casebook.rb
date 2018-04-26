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
# #

# Concrete class for a Casebook, the root node of a table of contents.
# - does not belong to a Casebook
# - has ordinals of []
# - can have children
# - can have collaborators of its own
class Content::Casebook < Content::Node
  has_ancestry orphan_strategy: :adopt

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

  def clone(owner: '', draft_mode: false)
    cloned_casebook = dup

    if building_draft?(owner, draft_mode)
      draft_mode_of_published_casebook = true
    end

    cloned_casebook.update(copy_of: self, collaborators:  [Content::Collaborator.new(user: owner, role: 'owner')], public: false, parent: self, draft_mode_of_published_casebook: draft_mode_of_published_casebook )
    cloned_casebook
  end

  def clone_contents
    CloneCasebook.perform(self)
  end

  def merge_draft_into_published
    draft_casebook = self
    published_casebook = self.parent
    MergeDraftIntoPublishedCasebook.new(draft_casebook, published_casebook)
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
      User.joins(:content_collaborators).where(content_collaborators: { content_id: self.root.id, role: 'owner' }).first ## make sure this returns root
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

  def draft
    descendants.where(draft_mode_of_published_casebook: true).where(copy_of_id: self.id).first
  end

  def building_draft?(owner, draft_mode)
    self.owner == owner && self.public && draft_mode
  end
end
