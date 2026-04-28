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

  def normalize_zipnote_diffs(diff)
    normalize_diff_details(diff)
    diff
  end

  def normalize_diff_details(detail)
    detail["details"]&.each { |subdetail| normalize_diff_details(subdetail) }

    return unless detail["unified_diff"].present?
    return unless [detail["source1"], detail["source2"]].compact.any? { |source| source.include?("zipnote") }

    detail["unified_diff"] = sort_zipnote_filename_diff(detail["unified_diff"])
  end

  def sort_zipnote_filename_diff(diff)
    filename_lines, other_lines = diff.lines.partition do |line|
      line.start_with?("-Filename: ") || line.start_with?("+Filename: ")
    end

    removed = filename_lines.select { |line| line.start_with?("-Filename: ") }.sort_by { |line| zipnote_sort_key(line) }
    added = filename_lines.select { |line| line.start_with?("+Filename: ") }.sort_by { |line| zipnote_sort_key(line) }

    return diff if removed.empty? || added.empty? || removed.length != added.length

    removed.zip(added).flat_map { |old_line, new_line| [old_line, new_line] }.join + other_lines.join
  end

  def zipnote_sort_key(line)
    line.sub(/^[+-]Filename: /, '').sub(%r{^[^/]+/}, '')
  end

  def generate_diff
    result = Diffoscope.compare(url_1, url_2, new_file: true)
    update!(
      results: { diff: normalize_zipnote_diffs(result.to_h) },
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
