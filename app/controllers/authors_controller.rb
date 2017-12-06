class AuthorsController < ApplicationController
  def index
    users = []
    owners = Content::Collaborator.where(role: 'owner')
    
    owners.each do |owner|
      users << User.find(owner.user_id).display_name
    end
    
    a = users.sort.uniq
    render json: a
  end
end