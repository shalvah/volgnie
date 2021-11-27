require 'redis'

redis_options = {
  host: ENV.fetch('REDIS_HOSTNAME'),
  port: ENV.fetch('REDIS_PORT'),
  db: default_if_empty(ENV["REDIS_DB"], 0),
  timeout: 10,
}
redis_options[:password] = ENV['REDIS_PASSWORD'] unless really_empty?(ENV['REDIS_PASSWORD'])

Cache = Redis.new(redis_options)
TWO_DAYS = 2 * 24 * 60 * 60