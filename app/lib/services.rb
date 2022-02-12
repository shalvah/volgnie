# frozen_string_literal: true

require_relative './event_dispatchers'
require 'redis'
require_relative '../helpers'


# Poor man's service container
class Services
  Bindings = {
    dispatcher: lambda {
      {
        "production" => SnsDispatcher,
        "development" => LocalDispatcher,
        "test" => FakeDispatcher,
      }[ENV.fetch("APP_ENV")].new
    },

    lambda_client: lambda {
      ENV["IS_OFFLINE"] ? Aws::Lambda::Client.new({endpoint: 'http://localhost:3002'})
        : Aws::Lambda::Client.new
    },
  }

  class << self
    @@__resolved = {}

    def register(key, &value)
      Bindings[key] = value
    end

    def [](key)
      raise StandardError.new("Unknown config key #{key}") unless Bindings.has_key?(key)
      @@__resolved[key] ||= Bindings[key].call
    end

    # Override a resolved service
    def []=(key, value)
      raise StandardError.new("Unknown config key #{key}") unless Bindings.has_key?(key)
      @@__resolved[key] = value
    end

    def __clear_resolved
      @@__resolved = {}
    end
  end
end