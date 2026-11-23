require 'test_helper'

class ApiV1JobsControllerTest < ActionDispatch::IntegrationTest
  test 'submit a job' do
    post api_v1_jobs_path(url_1: 'https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz', url_2: 'https://registry.npmjs.org/log-event/-/log-event-1.1.2.tgz')
    assert_response :redirect
    assert_match /\/api\/v1\/jobs\//, @response.location
  end

  test 'submit an invalid job' do
    post api_v1_jobs_path
    assert_response :bad_request

    actual_response = JSON.parse(@response.body)

    assert_equal actual_response["title"], "Bad Request"
    assert_equal actual_response["details"], ["Url 1 can't be blank", "Url 2 can't be blank"]
  end

  test 'submit purls' do
    post api_v1_jobs_path(url_1: 'pkg:gem/rake@13.0.0', url_2: 'pkg:gem/rake@13.0.1')
    assert_response :redirect
  end

  test 'refuses local paths' do
    local_file = Rails.root.join('config', 'database.yml').to_s
    Diffoscope.expects(:compare).never

    [[local_file, 'https://example.com/b.tgz'], ['https://example.com/a.tgz', local_file], ['file:///etc/passwd', 'https://example.com/b.tgz']].each do |url_1, url_2|
      assert_no_difference 'Job.count' do
        Sidekiq.testing!(:inline) { post api_v1_jobs_path(url_1: url_1, url_2: url_2) }
      end
      assert_response :bad_request
      assert_match 'must be an http(s) URL or a purl', JSON.parse(@response.body)['details'].join
    end
  end

  test 'refuses to fetch loopback, private and metadata addresses' do
    Diffoscope::Runner.expects(:new).never
    stub_request(:get, 'https://example.com/b.tgz').to_return(status: 200, body: 'b')

    ['http://127.0.0.1:3000/', 'http://10.0.0.5/a.tgz', 'http://169.254.169.254/latest/meta-data/', 'http://[::1]/a.tgz'].each do |url|
      Sidekiq.testing!(:inline) { post api_v1_jobs_path(url_1: url, url_2: 'https://example.com/b.tgz') }
      assert_response :redirect

      job = Job.order(:created_at).last
      assert_equal 'error', job.status, url
      assert_match 'Address not allowed', job.results['errors'].join, url
    end
    assert_not_requested :get, /.*/
  end

  test 'refuses a redirect to a private address' do
    Diffoscope::Runner.expects(:new).never
    stub_request(:get, 'https://example.com/a.tgz').to_return(status: 302, headers: { 'Location' => 'http://169.254.169.254/latest/meta-data/' })

    Sidekiq.testing!(:inline) { post api_v1_jobs_path(url_1: 'https://example.com/a.tgz', url_2: 'https://example.com/b.tgz') }

    job = Job.order(:created_at).last
    assert_equal 'error', job.status
    assert_match 'Address not allowed', job.results['errors'].join
    assert_not_requested :get, /169\.254/
  end

  test 'marks a download that times out as an error' do
    Diffoscope::Runner.expects(:new).never
    stub_request(:get, 'https://example.com/a.tgz').to_timeout

    Sidekiq.testing!(:inline) { post api_v1_jobs_path(url_1: 'https://example.com/a.tgz', url_2: 'https://example.com/b.tgz') }

    job = Job.order(:created_at).last
    assert_equal 'error', job.status
    assert_match 'timed out', job.results['errors'].join
  end

  test 'check on a job' do
    @job = Job.create(url_1: 'https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz', url_2: 'https://registry.npmjs.org/log-event/-/log-event-1.1.2.tgz')
    
    @job.expects(:check_status)
    Job.expects(:find).with(@job.id).returns(@job)

    get api_v1_job_path(id: @job.id)
    assert_response :success
    assert_template 'jobs/show', file: 'jobs/show.json.jbuilder'
    
    actual_response = JSON.parse(@response.body)

    assert_equal actual_response["url_1"], @job.url_1
    assert_equal actual_response["url_2"], @job.url_2
  end
end