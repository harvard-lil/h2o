class AuthorsController < ApplicationController
  def index
    a = ['ice cream', 'hamburger', 'potato']
    render json: a
  end
end