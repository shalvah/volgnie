if ENV["APP_ENV"] != "test"
  require 'honeybadger'
  Honeybadger.configure do |h|
    h.exceptions.ignore += ["Purge::OutOfTime"]
    h.env = ENV["APP_ENV"]
  end
end
require_relative './app/config'
require_relative './app/models'
require_relative './app/helpers'
require_relative './app/lib/services'
require_relative './app/lib/cache'
require_relative './app/lib/twitter'
require_relative './app/events'