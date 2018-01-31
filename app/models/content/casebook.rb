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
  has_many :collaborators, class_name: 'Content::Collaborator', dependent: :destroy, inverse_of: :content, foreign_key: :casebook_id

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
    cloned_casebook.update(copy_of: self, collaborators:  [Content::Collaborator.new(user: owner, role: 'owner')], public: false, parent: self )
    cloned_casebook
  end

  def clone_contents
    connection = ActiveRecord::Base.connection
    columns = self.class.column_names - %w{id casebook_id copy_of_id is_alias}
    query = <<-SQL
      INSERT INTO content_nodes(#{columns.join ', '},
        copy_of_id,
        casebook_id,
        is_alias
      )
      SELECT #{columns.join ', '},
        id,
        #{connection.quote(id)},
        #{connection.quote(true)}
      FROM content_nodes WHERE casebook_id=#{connection.quote(copy_of.id)};
    SQL
    ActiveRecord::Base.connection.execute(query)
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
      User.joins(:content_collaborators).where(content_collaborators: { casebook_id: self.root.id, role: 'owner' }).first ## make sure this returns root
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
