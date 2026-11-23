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

  test 'shows a download error' do
    Diffoscope::Runner.expects(:new).never
    stub_request(:get, 'https://example.com/a.tgz').to_return(status: 404)
    params = { url_1: 'https://example.com/a.tgz', url_2: 'https://example.com/b.tgz' }

    Sidekiq.testing!(:inline) { get diff_path(params) }
    get diff_path(params)

    assert_response :success
    assert_select 'code', text: /Failed to download https:\/\/example.com\/a.tgz: HTTP 404/
  end

  test 'shows a diff of two plain files with the same filename' do
    stub_request(:get, 'https://a.example.com/notes.txt').to_return(status: 200, body: "one\ntwo\n")
    stub_request(:get, 'https://b.example.com/notes.txt').to_return(status: 200, body: "one\nthree\n")
    output = { source1: 'x', source2: 'y', unified_diff: "@@ -1,2 +1,2 @@\n one\n-two\n+three\n" }.to_json
    compared = nil
    Diffoscope::Runner.stubs(:executable).returns('/usr/bin/diffoscope')
    Open3.stubs(:capture3).with { |*command| compared = command[1..2].map { |path| File.read(path) } }
      .returns([output, '', stub(success?: false)])
    params = { url_1: 'https://a.example.com/notes.txt', url_2: 'https://b.example.com/notes.txt' }

    Sidekiq.testing!(:inline) { get diff_path(params) }
    get diff_path(params)

    assert_equal ["one\ntwo\n", "one\nthree\n"], compared
    assert_select 'pre#diff', text: /diff --git a\/notes.txt b\/notes.txt.*-two.*\+three/m
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
