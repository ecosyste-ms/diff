class ApplicationController < ActionController::Base
  skip_forgery_protection
  before_action { request.session_options[:skip] = true }

  # remote_ip stops at the nearest public proxy, which is never the client
  def client_ip
    IPAddr.new(request.headers['CF-Connecting-IP'].to_s.strip).to_s
  rescue IPAddr::Error
    request.remote_ip
  end
end
