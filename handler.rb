require 'bundler/setup'
require 'honeybadger' unless ENV["APP_ENV"] === "test"
require_relative './app/config'
require_relative './app/lib/services'
require_relative './app/lib/cache'
require_relative './app/lib/twitter'
require_relative './app/helpers'
require_relative './app/events'
require_relative './app/purge/purger'
require_relative './app/purge/preparer'
require_relative './app/purge/cleaner'

def start_purge(event:, context:)
  payload = get_sns_payload event
  preparer = Purge::Preparer.build(payload)
  Events.fetched_followers(*preparer.prepare)
end

def purge_followers(event:, context:)
  payload = get_sns_payload event
  purger = Purge::Purger.build(payload["user"], payload["purge_config"]) { context.get_remaining_time_in_millis }

  begin
    purger.purge(payload["followers"])
  rescue Purge::ErrorDuringPurge => e
    # If an error occurs, serialize state so we can resume
    unless ENV["APP_ENV"] == "test"
      Honeybadger.context({
        aws_request_id: context["aws_request_id"],
        user: payload["user"],
        last_processed: e.last_processed,
        total_size: payload["followers"].size,
      })
    end
    # serialize
    raise
  end

  Events.purge_finish(payload["user"], payload["purge_config"])
end

def finish_purge(event:, context:)
  payload = get_sns_payload event

  cleaner = Purge::Cleaner.build(payload["user"], payload["purge_config"])
  cleaner.clean
end

# Only meant for direct invocation, to test a specific piece of functionality
def sanities(event:, context:)
  Honeybadger.configure { |h| h.report_data = false }
  require_relative "./sanities/#{event}"
end