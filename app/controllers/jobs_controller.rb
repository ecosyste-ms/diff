class JobsController < ApplicationController
  def diff
    raise ActionController::RoutingError.new('Not Found') if params[:url_1].blank? || params[:url_2].blank?
    @job = Job.find_by(url_1: params[:url_1], url_2: params[:url_2])
    if @job.nil?
      @job = Job.create(url_1: params[:url_1], url_2: params[:url_2], status: 'pending', ip: request.remote_ip)
      @job.generate_diff_async
    end
  end
end