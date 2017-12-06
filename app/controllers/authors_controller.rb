class AuthorsController < ApplicationController
  def index
    authors = User.includes(:content_collaborators).
      where("lower(attribution) like ?", "%#{params[:term].downcase}%").
      where("content_collaborators.role = ?", "owner").
      references(:content_collaborators).
      pluck(:attribution)

    render json: authors.sort.uniq
  end
end