require 'sinatra'
require 'omniauth'
require 'omniauth/strategies/twitter'
require 'rack/protection'
require_relative './helpers'
require_relative '../lib/twitter'

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

  erb :index, locals: { csrf_token: session[:csrf] } #
end

twitter = TwitterApi.new(
  ENV.fetch('TWITTER_API_KEY'),
  ENV.fetch('TWITTER_API_KEY_SECRET'),
)
get '/auth/twitter/callback' do
  cache_control :no_store

  auth_info = request.env['omniauth.auth']

  creds = auth_info.credentials
  # User will be something like
  # {
  #     "username": "theshalvah",
  #     "name": "jukai (樹海)",
  #     "id": "876342319217332225",
  #     "public_metrics": {
  #       "followers_count": 7354,
  #       "following_count": 138,
  #       "tweet_count": 43875,
  #       "listed_count": 62
  #     },
  #     "profile_image_url": "https://pbs.twimg.com/profile_images/1348334243898945536/1r1J6_vE_normal.jpg",
  #     "protected": false
  # }
  session[:user] = twitter.as_user(creds[:token], creds[:secret]).get_user(auth_info.uid)["data"]
  # save_user(creds, session[:user])
  redirect '/purge/start'
end

get '/purge/start' do
  erb "Ready to begin, #{current_user["username"]}?"
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

# User clicked "Cancel"
get '/auth/failure' do
  session[:flash] = {error: "Something went wrong. Please try logging in again."}
  redirect "/"
end