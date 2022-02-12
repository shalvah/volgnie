# frozen_string_literal: true

require 'honeybadger' unless ENV["APP_ENV"] === "test"
require 'sinatra'
require 'omniauth'
require 'omniauth/strategies/twitter'
require 'rack/protection'
require_relative './config'
require_relative './models'
require_relative './lib/services'
require_relative './helpers'
require_relative './web_helpers'
require_relative 'lib/twitter'
require_relative 'lib/cache'
require_relative './events'
require_relative './purge//criteria'

set :sessions, expire_after: TWO_DAYS
set :session_secret, ENV.fetch('SESSION_SECRET')
set :views, settings.root + '/../views'
set :show_exceptions, test? ? false : :after_handler

before do
  # This is needed because sls-rack sets rack.errors (the error logger) to stderr
  # And sls-offline sends stderr to browser
  env["rack.errors"] = $stdout if ENV["IS_OFFLINE"]
end

use Rack::Protection::AuthenticityToken unless test?
OmniAuth.config.allowed_request_methods = [:post]
use OmniAuth::Builder do
  provider :twitter, ENV.fetch('TWITTER_API_KEY'), ENV.fetch('TWITTER_API_KEY_SECRET'), {
    use_authorize: true,
    callback_url: ENV.fetch('TWITTER_CALLBACK_URL'),
  }
end

get '/' do
  erb :index
end

get '/auth/twitter/callback' do
  cache_control :no_store

  auth_info = request.env['omniauth.auth']
  creds = auth_info.credentials
  session[:user] = Services[:twitter].as_user(creds[:token], creds[:secret]).get_user(auth_info[:uid])
  Services[:cache].multi do
    Services[:cache].set("keys-#{auth_info[:uid]}", creds.to_json, ex: TWO_DAYS)
    Services[:cache].set("user-#{auth_info[:uid]}", session[:user].to_json, ex: TWO_DAYS)
  end
  redirect '/purge/start'
end

# User clicked "Cancel" on Twitter's Authorization page
get '/auth/failure' do
  set_flash_error "Something went wrong. Please try logging in again."
  redirect "/"
end

get '/purge/start' do
  # todo if protected
  redirect '/' if !current_user
  erb :start
end

post '/purge/start' do
  redirect '/' if !current_user
  halt 400, "Missing parameters" if !params[:email] || !params[:level]

  purge_config = {
    report_email: params[:email],
    level: params[:level].to_i,
    trigger_time: Time.now.strftime("%B %-d, %Y at %H:%M:%S UTC%z"), # December 24, 2021 at 01:20:36 UTC+0100
    __simulate: AppConfig[:admins].include?(current_user["username"]) ? params[:__simulate] == "on" : false,
  }

  # Don't let them fire purge multiple times
  if Services[:cache].set("purge-config-#{current_user["id"]}", purge_config.to_json, nx: true, ex: AppConfig[:purge_lock_duration])
    Events.purge_start(AppUser.from_twitter_user(current_user), purge_config)
  end

  erb :started, locals: {email: params[:email]}
end

error do
  status 500
  content_type :html

  "Something went wrong, but we're looking into it! Please try again in a bit."
end