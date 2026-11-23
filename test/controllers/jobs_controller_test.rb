require 'test_helper'

class JobsControllerTest < ActionDispatch::IntegrationTest
  test 'starts processing a diff' do
    assert_difference 'GenerateDiffWorker.jobs.size', 1 do
      get diff_path(url_1: 'https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz', url_2: 'https://registry.npmjs.org/log-event/-/log-event-1.1.2.tgz')
    end
    assert_response :success
    assert_template 'jobs/diff'
  end

  test 'starts processing a diff of purls' do
    get diff_path(url_1: 'pkg:gem/rake@13.0.0', url_2: 'pkg:gem/rake@13.0.1')
    assert_response :success
    assert_template 'jobs/diff'
  end

  test 'refuses local paths' do
    local_file = Rails.root.join('config', 'database.yml').to_s
    Diffoscope.expects(:compare).never

    [[local_file, 'https://example.com/b.tgz'], ['https://example.com/a.tgz', local_file], ['file:///etc/passwd', 'https://example.com/b.tgz']].each do |url_1, url_2|
      assert_no_difference 'Job.count' do
        Sidekiq.testing!(:inline) { get diff_path(url_1: url_1, url_2: url_2) }
      end
      assert_response :unprocessable_content
    end
  end

  test 'does not serve an existing job for a local path' do
    local_file = Rails.root.join('config', 'database.yml').to_s
    job = Job.new(url_1: local_file, url_2: 'https://example.com/b.tgz', status: 'complete', results: { diff: { details: [{ source1: 'a', source2: 'b', unified_diff: 'leaked' }] } })
    job.save!(validate: false)

    get diff_path(url_1: job.url_1, url_2: job.url_2)
    assert_response :unprocessable_content
    assert_no_match 'leaked', response.body
  end
end
