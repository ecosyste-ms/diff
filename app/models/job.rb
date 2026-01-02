class Job < ApplicationRecord
  validates_presence_of :url_1, :url_2
  validates_uniqueness_of :id

  scope :status, ->(status) { where(status: status) }

  def self.clean_up
    Job.status(["complete",'error']).where('created_at < ?', 1.week.ago).in_batches.delete_all
  end

  def self.check_statuses
    Job.where(status: ["queued", "working"]).find_each(&:check_status)
  end

  def check_status
    return if sidekiq_id.blank?
    return if finished?
    update(status: fetch_status)
  end

  def fetch_status
    Sidekiq::Status.status(sidekiq_id).presence || 'error'
  end

  def finished?
    ['complete', 'error'].include?(status)
  end

  def generate_diff_async
    sidekiq_id = GenerateDiffWorker.perform_async(id)
    update(sidekiq_id: sidekiq_id)
  end

  def to_s
    id
  end

  def basename_1
    File.basename(url_1)
  end

  def basename_2
    File.basename(url_2)
  end

  def details
    return nil if results["diff"].nil?
    result = Diffoscope::Result.new(results["diff"])
    result.to_unified_diff
  end

  def generate_diff
    result = Diffoscope.compare(url_1, url_2, new_file: true)
    update!(
      results: { diff: result.to_h },
      status: 'complete',
      sha256_1: result.sha256_1,
      sha256_2: result.sha256_2
    )
  rescue Diffoscope::DownloadError => e
    update!(results: { errors: [e.message] }, status: 'error')
  rescue => e
    update(results: { error: e.inspect }, status: 'error')
  end
end
