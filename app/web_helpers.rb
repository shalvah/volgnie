# frozen_string_literal: true

def current_user
  session[:user]
end

def csrf_token
  session[:csrf]
end

def has_flash_error
  !!session[:flash][:error] rescue false
end

def get_flash_error
  error_message = session[:flash] ? session[:flash][:error] : nil
  session[:flash][:error] = nil
  error_message
end

def set_flash_error(message)
  session[:flash] ||= {}
  session[:flash][:error] = message
end

def current_user_follower_limit_text
  limit = AppConfig[:default_follower_limit]
  Integer(current_user.public_metrics["followers_count"]) >= limit ? "your latest #{limit}" : "all your"
end