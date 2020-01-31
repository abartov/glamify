require 'test_helper'

class GlamifyControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get login" do
    get :login
    assert_response :success
  end

  test "should get results" do
    get :results
    assert_response :success
  end

end
