# frozen_string_literal: true

at_exit { defined?(OTelProcessor) && OTelProcessor.shutdown(timeout: 10) }

require 'sinatra'
require_relative './bootstrap'
require 'omniauth'
require 'omniauth/strategies/twitter'
require 'rack/protection'
require_relative './web_helpers'
require_relative './purge/criteria'

set :sessions, expire_after: ONE_DAY
set :session_secret, ENV.fetch('SESSION_SECRET')
set :views, settings.root + '/../views'

use Rack::Protection::AuthenticityToken unless test?
OmniAuth.config.allowed_request_methods = [:post]
use OmniAuth::Builder do
  provider :twitter, ENV.fetch('TWITTER_API_KEY'), ENV.fetch('TWITTER_API_KEY_SECRET'), {
    use_authorize: true,
    callback_url: ENV.fetch('TWITTER_CALLBACK_URL'),
  }
end

unless test?
  before do
    if session[:user]
      current_span = OpenTelemetry::Trace.current_span
      current_span.set_attribute("user", session[:user].to_json)
      current_span.set_attribute("user.id", session[:user][:id])
    end
  end
end

  get('/') { erb :index }

  get '/auth/twitter/callback' do
    cache_control :no_store

    auth = request.env['omniauth.auth']
    creds = auth.credentials
    session[:user] = Services[:twitter].as_user(creds[:token], creds[:secret]).get_user(auth[:uid])
    Services[:cache].multi do |c|
      c.set("keys-#{auth[:uid]}", creds.to_json, ex: TWO_DAYS)
      c.set("user-#{auth[:uid]}", session[:user].to_json, ex: TWO_DAYS)
    end
    redirect '/purge/start'
  end

  # User clicked "Cancel" on Twitter's Authorization page
  get '/auth/failure' do
    set_flash_error "Something went wrong. Please try logging in again."
    redirect "/"
  end

  post('/auth/logout') { session.clear && redirect('/') }

  get '/purge/start' do
    redirect '/' if !current_user
    erb current_user.protected ? :unlock_account : :start
  end

  post '/purge/refresh-account' do
    redirect '/' unless current_user&.protected

    creds = get_user_creds(current_user.id)
    updated = Services[:twitter].as_user(creds["token"], creds["secret"]).get_user(current_user.id)
    redirect '/purge/start' if updated.protected

    session[:user] = updated
    Services[:cache].set("user-#{updated.id}", updated.to_json, ex: TWO_DAYS)
    redirect '/purge/start'
  end

  post '/purge/start' do
    redirect '/' if !current_user || current_user.protected
    halt 400, "Missing parameters" if !params[:email] || !params[:level]

    purge_config = PurgeConfig.from({
      report_email: params[:email],
      level: params[:level].to_i,
      __simulate: AppConfig[:admins].include?(current_user.username) ? params[:__simulate] == "on" : false,
    })

    # Don't let them fire purge multiple times
    if Services[:cache].set("purge-config-#{current_user["id"]}", purge_config.to_json, nx: true, ex: AppConfig[:purge_lock_duration])
      Events.purge_start(AppUser.from(current_user), purge_config)
    end

    erb :started, locals: { email: params[:email] }
  end

  error do
    status 500
    content_type :html

    "Something went wrong, but we're looking into it! Please try again in a bit."
  end