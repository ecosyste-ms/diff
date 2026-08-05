require 'test_helper'

class CacheHeadersTest < ActionDispatch::IntegrationTest
  test 'html pages do not set cookies' do
    get root_path
    assert_response :success
    assert_nil response.headers['Set-Cookie']
  end
end
