require 'test_helper'

class CaseCitationsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:case_citations)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create case_citation" do
    assert_difference('CaseCitation.count') do
      post :create, :case_citation => { }
    end

    assert_redirected_to case_citation_path(assigns(:case_citation))
  end

  test "should show case_citation" do
    get :show, :id => case_citations(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => case_citations(:one).to_param
    assert_response :success
  end

  test "should update case_citation" do
    put :update, :id => case_citations(:one).to_param, :case_citation => { }
    assert_redirected_to case_citation_path(assigns(:case_citation))
  end

  test "should destroy case_citation" do
    assert_difference('CaseCitation.count', -1) do
      delete :destroy, :id => case_citations(:one).to_param
    end

    assert_redirected_to case_citations_path
  end
end
