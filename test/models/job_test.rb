require "test_helper"

class JobTest < ActiveSupport::TestCase
  context 'validations' do
    should validate_presence_of(:url_1)
    should validate_presence_of(:url_2)
    should validate_uniqueness_of(:id).case_insensitive
  end

  setup do
    @job = Job.create(url_1: 'https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz', url_2: 'https://registry.npmjs.org/log-event/-/log-event-1.1.2.tgz', sidekiq_id: '123', ip: '123.456.78.9')
  end

  test 'check_status' do
    Sidekiq::Status.expects(:status).with(@job.sidekiq_id).returns(:queued)
    @job.check_status
    assert_equal @job.status, "queued"
  end

  test 'generate_diff_async' do
    GenerateDiffWorker.expects(:perform_async).with(@job.id)
    @job.generate_diff_async
  end

  test 'diff' do
    Dir.mktmpdir do |dir|
      FileUtils.cp(File.join(file_fixture_path, 'log-event-1.1.1.tgz'), dir)
      FileUtils.cp(File.join(file_fixture_path, 'log-event-1.1.2.tgz'), dir)
      results = @job.diff(dir)
      
      assert_equal results[:diff].keys, ["diffoscope-json-version", "source1", "source2", "unified_diff", "details"]
    end
  end

  test 'download_file' do
    stub_request(:get, "https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz")
      .to_return({ status: 200, body: file_fixture('log-event-1.1.1.tgz') })

    Dir.mktmpdir do |dir|
      sha256 = @job.download_file("https://registry.npmjs.org/log-event/-/log-event-1.1.1.tgz", dir)
      assert_equal sha256, '9c7c23280d813b48c20f10af6401e9eb4d09115e2c5468fa0a582164c92b779a'
    end
  end
end
