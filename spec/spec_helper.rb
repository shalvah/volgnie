require 'dotenv'
Dotenv.load(File.expand_path("../.env.test", __dir__))

require "mock_redis"
require "factory_bot"
require "faker"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
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

def purge_payload(user, level)
  {
    "user" => {
      "id" => user[:id],
      "following_count" => user[:following].size,
      "followers_count" => user[:followers].size,
      "username" => user[:username],
    },
    "purge_config" => {
      "report_email" => "test@volgnie.com",
      "level" => level,
      "trigger_time" => Time.now.strftime("%B %-d, %Y at %H:%M:%S UTC%z"),
    }
  }
end