ENV['APP_ENV'] = 'test'
ENV['SESSION_SECRET'] = 'test'
ENV['TWITTER_API_KEY'] = 'test'
ENV['TWITTER_API_KEY_SECRET'] = 'test'
ENV['TWITTER_CALLBACK_URL'] = 'http://localhost:9787/auth/twitter/callback'
ENV['REDIS_HOSTNAME'] = 'localhost'
ENV['REDIS_PORT'] = '6379'
ENV['AWS_REGION'] = 'test'
ENV['AWS_ACCESS_KEY_ID'] = 'test'
ENV['AWS_SECRET_ACCESS_KEY'] = 'test'
ENV["CLOUDWATCH_METRICS"] = "off"

require 'honeybadger'
Honeybadger.configure { |c| c.report_data = false }

require 'mock_redis'
require 'redis'
# Not the cleanest, I know
class Redis
  def self.new(*args)
    MockRedis.new *args
  end
end

require "factory_bot"
require "faker"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run focus: true
  config.shared_context_metadata_behavior = :apply_to_host_groups

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.include FactoryBot::Syntax::Methods
  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.disable_monkey_patching!
  config.order = :random
end

def fixture(path)
  File.open(File.join("spec", "fixtures", "#{path.to_s}.json"))
end

def stringify_keys(hash)
  hash.each_with_object({}) do |(k, v), obj|
    obj[k.to_s] = v
  end
end