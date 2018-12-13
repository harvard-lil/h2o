class Content::Casebook < Content::Node
  has_ancestry orphan_strategy: :adopt

  default_scope {where(casebook_id: nil)}

  validates :casebook_id, presence: false
  validates_length_of :ordinals, is: 0

  has_many :contents, -> {order :ordinals}, class_name: 'Content::Child', inverse_of: :casebook, foreign_key: :casebook_id, dependent: :delete_all
  has_many :collaborators, -> {order role: :desc}, class_name: 'Content::Collaborator', dependent: :destroy, inverse_of: :content, foreign_key: :content_id
  has_many :unpublished_revisions, dependent: :destroy

  include Content::Concerns::HasCollaborators
  include Content::Concerns::HasChildren

  after_create :clone_contents, if: -> {copy_of.present?}

  searchable do
    text :title, boost: 3.0
    text :subtitle
    text :headnote
    string(:klass, stored: true) { self.class.name }
    string(:display_name, stored: true) { title }
    string(:attribution, stored: true) { owners.first.try(:attribution) }
    string(:affiliation, stored: true) { owners.first.try(:affiliation) }
    string(:verified_professor, stored: true) { owners.first.try(:verified_professor) }
    boolean :public

    integer :owner_ids, stored: true, multiple: true do
      owners.map &:id
    end
  end

  def clone(draft_mode, current_user)
    if draft_mode
      cloned_casebook = self.deep_clone include: :collaborator
      cloned_casebook.update(copy_of: self, public: false, parent: self, draft_mode_of_published_casebook: true )
    else
      cloned_casebook = self.dup
      cloned_casebook.update(copy_of: self, collaborators:  [Content::Collaborator.new(user: current_user, role: 'owner', has_attribution: true)], public: false, parent: self )
    end

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

  def draft
    descendants.where(draft_mode_of_published_casebook: true).where(copy_of_id: self.id).first
  end

  def building_draft?(owner, draft_mode)
    self.owner == owner && self.public && draft_mode
  end

  def resources_have_annotations?
    resources.each do |resource|
      if resource.annotations.any?
        return true
      end
    end
    false
  end
end
