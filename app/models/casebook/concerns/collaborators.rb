module Casebook::Concerns::Collaborators
  extend ActiveSupport::Concern

  included do
      has_many :users, class_name: 'User', through: :collaborators
      has_many :owners, -> {where casebook_collaborators: {role: 'owner'}}, class_name: 'User', through: :collaborators, source: :user
      has_many :editors, -> {where casebook_collaborators: {role: 'editor'}}, class_name: 'User', through: :collaborators, source: :user
      has_many :reviewers, -> {where casebook_collaborators: {role: 'reviewer'}}, class_name: 'User', through: :collaborators, source: :user
  end
end
