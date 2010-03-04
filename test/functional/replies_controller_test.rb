require 'test_helper'

class RepliesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:replies)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create reply" do
    assert_difference('Reply.count') do
      post :create, :reply => { }
    end

    assert_redirected_to reply_path(assigns(:reply))
  end

  test "should show reply" do
    get :show, :id => replies(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => replies(:one).to_param
    assert_response :success
  end

  test "should update reply" do
    put :update, :id => replies(:one).to_param, :reply => { }
    assert_redirected_to reply_path(assigns(:reply))
  end

  test "should destroy reply" do
    assert_difference('Reply.count', -1) do
      delete :destroy, :id => replies(:one).to_param
    end

    assert_redirected_to replies_path
  end
end
