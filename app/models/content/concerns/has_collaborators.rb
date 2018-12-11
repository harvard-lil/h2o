# Concerns relevant to any Node that can have collaborators
# - allows Child nodes to expose the same API as Casebooks, using the collaborator association defined by their Casebook
module Content::Concerns::HasCollaborators
  extend ActiveSupport::Concern

  included do
    has_many :users, class_name: 'User', through: :collaborators, source: :user, inverse_of: :content_collaborators
    has_many :editors, -> {where content_collaborators: {role: 'editor'}}, class_name: 'User', through: :collaborators, source: :user
    has_many :owners, -> {where content_collaborators: {role: 'owner'}}, class_name: 'User', through: :collaborators, source: :user do
      
      def << (*users)
        self.collaborators << users.map {|user| Content::Collaborator.new(user: user, role: 'owner')}
      end
    end

    has_many :attributors, -> {where(content_collaborators: {has_attribution: true}).order('role desc')}, class_name: 'User', through: :collaborators, source: :user

    def owners= (users)
      self.collaborators = (self.collaborators || []).reject {|c| c.role == 'owner'} + users.map {|user| Content::Collaborator.new(user: user, role: 'owner')}
    end
  end
end
