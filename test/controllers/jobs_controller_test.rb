require 'test_helper'

class JobsControllerTest < ActionDispatch::IntegrationTest
  test 'starts processing a diff' do
    get diff_path(url_1: 'https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz', url_2: 'https://registry.npmjs.org/log-event/-/log-event-1.1.2.tgz')
    assert_response :success
    assert_template 'jobs/diff'
  end
end