require 'test_helper'

class QuestionsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:questions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create question" do
    assert_difference('Question.count') do
      post :create, :question => { }
    end

    assert_redirected_to question_path(assigns(:question))
  end

  test "should show question" do
    get :show, :id => questions(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => questions(:one).to_param
    assert_response :success
  end

  test "should update question" do
    put :update, :id => questions(:one).to_param, :question => { }
    assert_redirected_to question_path(assigns(:question))
  end

  test "should destroy question" do
    assert_difference('Question.count', -1) do
      delete :destroy, :id => questions(:one).to_param
    end

    assert_redirected_to questions_path
  end
end
