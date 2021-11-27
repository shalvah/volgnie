# frozen_string_literal: true

require 'sinatra'
require 'omniauth'
require 'omniauth/strategies/twitter'
require 'rack/protection'
require_relative './helpers'
require_relative './web_helpers'
require_relative '../lib/twitter'
require_relative '../lib/cache'
require_relative './events'

set :sessions, expire_after: 2 * 24 * 60 * 60
set :session_secret, ENV.fetch('SESSION_SECRET')
set :views, settings.root + '/../views'

use Rack::Protection::AuthenticityToken
OmniAuth.config.allowed_request_methods = [:post]
use OmniAuth::Builder do
  provider :twitter, ENV.fetch('TWITTER_API_KEY'), ENV.fetch('TWITTER_API_KEY_SECRET'), {
    use_authorize: true,
    callback_url: ENV.fetch('TWITTER_CALLBACK_URL'),
  }
end

get '/' do
  # puts request.env['serverless.event']
  # puts request.env['serverless.context']

  erb :index
end

get '/auth/twitter/callback' do
  cache_control :no_store

  auth_info = request.env['omniauth.auth']
  creds = auth_info.credentials
  # User will be something like
  # {
  #   "username": "theshalvah",
  #   "name": "jukai (樹海)",
  #   "id": "876342319217332225",
  #   "public_metrics": {
  #     "followers_count": 7354,
  #     "following_count": 138,
  #     "tweet_count": 43875,
  #     "listed_count": 62
  #   },
  #   "profile_image_url": "https://pbs.twimg.com/profile_images/1348334243898945536/1r1J6_vE_normal.jpg",
  #   "protected": false
  # }
  session[:user] = Twitter.as_user(creds[:token], creds[:secret]).get_user(auth_info[:uid])["data"]
  Cache.multi do
    Cache.set("keys-#{auth_info[:uid]}", creds.to_json, ex: TWO_DAYS)
    Cache.set("user-#{auth_info[:uid]}", session[:user].to_json, ex: TWO_DAYS)
  end
  redirect '/purge/start'
end

# User clicked "Cancel" on Twitter's Authorization page
get '/auth/failure' do
  set_flash_error "Something went wrong. Please try logging in again."
  redirect "/"
end

get '/purge/start' do
  redirect '/' if !current_user
  erb :start
end

post '/purge/start' do
  redirect '/' if !current_user

  purge_config = {
    report_email: params[:email],
    level: 3
  }
  # Don't let them fire purge multiple times
  if Cache.set("purge-config-#{current_user["id"]}", purge_config.to_json, nx: true, ex: TWO_DAYS)
    Events.purge_start({
      id: current_user["id"],
      following_count: current_user["public_metrics"]["following_count"],
      followers_count: current_user["public_metrics"]["followers_count"],
      username: current_user["username"],
    }, purge_config)
  end
  erb :started
end

# TODO
set :show_exceptions, false

error do
  content_type :json
  status 500

  e = env['sinatra.error']
  response = { error: e.message, trace: e.backtrace }
  response.delete(:trace) if settings.production?
  response.to_json
end