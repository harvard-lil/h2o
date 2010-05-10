require 'test_helper'

class CasebooksControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:casebooks)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create casebook" do
    assert_difference('Casebook.count') do
      post :create, :casebook => { }
    end

    assert_redirected_to casebook_path(assigns(:casebook))
  end

  test "should show casebook" do
    get :show, :id => casebooks(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => casebooks(:one).to_param
    assert_response :success
  end

  test "should update casebook" do
    put :update, :id => casebooks(:one).to_param, :casebook => { }
    assert_redirected_to casebook_path(assigns(:casebook))
  end

  test "should destroy casebook" do
    assert_difference('Casebook.count', -1) do
      delete :destroy, :id => casebooks(:one).to_param
    end

    assert_redirected_to casebooks_path
  end
end
