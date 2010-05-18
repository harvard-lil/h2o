require 'test_helper'

class ExcerptsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:excerpts)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create excerpt" do
    assert_difference('Excerpt.count') do
      post :create, :excerpt => { }
    end

    assert_redirected_to excerpt_path(assigns(:excerpt))
  end

  test "should show excerpt" do
    get :show, :id => excerpts(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => excerpts(:one).to_param
    assert_response :success
  end

  test "should update excerpt" do
    put :update, :id => excerpts(:one).to_param, :excerpt => { }
    assert_redirected_to excerpt_path(assigns(:excerpt))
  end

  test "should destroy excerpt" do
    assert_difference('Excerpt.count', -1) do
      delete :destroy, :id => excerpts(:one).to_param
    end

    assert_redirected_to excerpts_path
  end
end
