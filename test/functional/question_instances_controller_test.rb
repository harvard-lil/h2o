require 'test_helper'

class QuestionInstancesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:question_instances)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create question_instance" do
    assert_difference('QuestionInstance.count') do
      post :create, :question_instance => { }
    end

    assert_redirected_to question_instance_path(assigns(:question_instance))
  end

  test "should show question_instance" do
    get :show, :id => question_instances(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => question_instances(:one).to_param
    assert_response :success
  end

  test "should update question_instance" do
    put :update, :id => question_instances(:one).to_param, :question_instance => { }
    assert_redirected_to question_instance_path(assigns(:question_instance))
  end

  test "should destroy question_instance" do
    assert_difference('QuestionInstance.count', -1) do
      delete :destroy, :id => question_instances(:one).to_param
    end

    assert_redirected_to question_instances_path
  end
end
