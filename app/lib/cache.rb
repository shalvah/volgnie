require 'redis'
require_relative '../helpers'

Services.register(:cache) do
  case ENV.fetch("APP_ENV")
  when "test"
    MockRedis.new
  else
    Redis.exists_returns_integer = true
    redis_options = {
      host: ENV.fetch('REDIS_HOSTNAME'),
      port: ENV.fetch('REDIS_PORT', "6379"),
      db: default_if_empty(ENV["REDIS_DB"], 0),
      timeout: 10,
      password: (ENV['REDIS_PASSWORD'] unless really_empty?(ENV['REDIS_PASSWORD']))
    }.compact
    Redis.new(redis_options)
  end
end

THREE_HOURS = 3 * 60 * 60
ONE_DAY = 24 * 60 * 60
TWO_DAYS = 2 * ONE_DAY