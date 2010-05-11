require 'test_helper'

class CaseDocketNumbersControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:case_docket_numbers)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create case_docket_number" do
    assert_difference('CaseDocketNumber.count') do
      post :create, :case_docket_number => { }
    end

    assert_redirected_to case_docket_number_path(assigns(:case_docket_number))
  end

  test "should show case_docket_number" do
    get :show, :id => case_docket_numbers(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => case_docket_numbers(:one).to_param
    assert_response :success
  end

  test "should update case_docket_number" do
    put :update, :id => case_docket_numbers(:one).to_param, :case_docket_number => { }
    assert_redirected_to case_docket_number_path(assigns(:case_docket_number))
  end

  test "should destroy case_docket_number" do
    assert_difference('CaseDocketNumber.count', -1) do
      delete :destroy, :id => case_docket_numbers(:one).to_param
    end

    assert_redirected_to case_docket_numbers_path
  end
end
