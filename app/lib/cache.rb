require 'redis'
require_relative '../helpers'

Services.register(:cache) do
  case ENV.fetch("APP_ENV")
  when "test"
    MockRedis.new
  else
    redis_options = {
      host: ENV.fetch('REDIS_HOSTNAME'),
      port: ENV.fetch('REDIS_PORT'),
      db: default_if_empty(ENV["REDIS_DB"], 0),
      timeout: 10,
      password: (ENV['REDIS_PASSWORD'] unless really_empty?(ENV['REDIS_PASSWORD']))
    }.compact
    Redis.new(redis_options)
  end
end

TWO_DAYS = 2 * 24 * 60 * 60