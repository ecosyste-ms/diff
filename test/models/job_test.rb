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

  test 'accepts http, https and purl inputs' do
    assert Job.new(url_1: 'http://example.com/a.tgz', url_2: 'pkg:gem/rails@7.0.0').valid?
  end

  test 'rejects inputs that are not urls or purls' do
    ['/etc/passwd', '/proc/self/environ', 'config/database.yml', '../Gemfile', 'file:///etc/passwd',
     'ftp://example.com/a.tgz', 'http://', 'https:///a.tgz', 'pkg:', "/etc/passwd\nhttps://example.com/"].each do |input|
      job = Job.new(url_1: input, url_2: 'https://example.com/b.tgz')
      assert_not job.valid?, input
      assert_equal ['Url 1 must be an http(s) URL or a purl'], job.errors.full_messages, input

      job = Job.new(url_1: 'https://example.com/a.tgz', url_2: input)
      assert_not job.valid?, input
    end
  end

  test 'clean_up removes jobs older than a week in any status' do
    old = %w[pending queued working complete error].map do |status|
      Job.create!(url_1: 'https://example.com/a.tgz', url_2: 'https://example.com/b.tgz', status: status, created_at: 8.days.ago)
    end
    recent = Job.create!(url_1: 'https://example.com/a.tgz', url_2: 'https://example.com/b.tgz', status: 'pending', created_at: 6.days.ago)

    Job.clean_up

    assert_empty Job.where(id: old.map(&:id))
    assert Job.exists?(recent.id)
    assert Job.exists?(@job.id)
  end

  test 'cron commands are defined rake tasks' do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    commands = JSON.parse(Rails.root.join('app.json').read)['cron'].map { |entry| entry['command'] }

    commands.each do |command|
      task = command[/rake (\S+)/, 1]
      assert Rake::Task.task_defined?(task), "#{task} is not a rake task"
    end
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

    Diffoscope.expects(:compare).with(@job.url_1, @job.url_2, new_file: true, local_files: false).returns(result)

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
