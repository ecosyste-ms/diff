class ApplicationController < ActionController::Base
  skip_forgery_protection
  before_action { request.session_options[:skip] = true }
end
