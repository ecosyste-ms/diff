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

  test 'generate_diff' do
    result = mock
    result.stubs(:to_h).returns({ "source1" => "a", "source2" => "b" })
    result.stubs(:sha256_1).returns("abc123")
    result.stubs(:sha256_2).returns("def456")

    Diffoscope.expects(:compare).with(@job.url_1, @job.url_2, new_file: true).returns(result)

    @job.generate_diff

    assert_equal "complete", @job.status
    assert_equal "abc123", @job.sha256_1
    assert_equal "def456", @job.sha256_2
  end

  test 'generate_diff handles download error' do
    Diffoscope.expects(:compare).raises(Diffoscope::DownloadError.new("Failed to download"))

    @job.generate_diff

    assert_equal "error", @job.status
    assert_includes @job.results["errors"], "Failed to download"
  end
end
