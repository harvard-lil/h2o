require 'test_helper'

class CaseJurisdictionsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:case_jurisdictions)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create case_jurisdiction" do
    assert_difference('CaseJurisdiction.count') do
      post :create, :case_jurisdiction => { }
    end

    assert_redirected_to case_jurisdiction_path(assigns(:case_jurisdiction))
  end

  test "should show case_jurisdiction" do
    get :show, :id => case_jurisdictions(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => case_jurisdictions(:one).to_param
    assert_response :success
  end

  test "should update case_jurisdiction" do
    put :update, :id => case_jurisdictions(:one).to_param, :case_jurisdiction => { }
    assert_redirected_to case_jurisdiction_path(assigns(:case_jurisdiction))
  end

  test "should destroy case_jurisdiction" do
    assert_difference('CaseJurisdiction.count', -1) do
      delete :destroy, :id => case_jurisdictions(:one).to_param
    end

    assert_redirected_to case_jurisdictions_path
  end
end
