require 'test_helper'

class CollagesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:collages)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create collage" do
    assert_difference('Collage.count') do
      post :create, :collage => { }
    end

    assert_redirected_to collage_path(assigns(:collage))
  end

  test "should show collage" do
    get :show, :id => collages(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => collages(:one).to_param
    assert_response :success
  end

  test "should update collage" do
    put :update, :id => collages(:one).to_param, :collage => { }
    assert_redirected_to collage_path(assigns(:collage))
  end

  test "should destroy collage" do
    assert_difference('Collage.count', -1) do
      delete :destroy, :id => collages(:one).to_param
    end

    assert_redirected_to collages_path
  end
end
