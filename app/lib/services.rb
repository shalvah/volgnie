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

    relationship_checker: lambda { Purge::RelationshipChecker },

    logger: lambda {
      l = Logger.new($stdout)
      l.formatter = proc do |severity, datetime, progname, msg|
        # AWS CloudWatch includes timestamps already
        env_is?("production") ? "#{severity}: #{msg}\n" : "[#{datetime}] #{severity}: #{msg}\n"
      end
      l
    }
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

    # Allows you to override a resolved service. Useful for testing
    def []=(key, value)
      raise StandardError.new("Unknown config key #{key}") unless Bindings.has_key?(key)
      @@__resolved[key] = value
    end

    def __clear_resolved
      @@__resolved = {}
    end
  end
end

def logger
  Services[:logger]
end