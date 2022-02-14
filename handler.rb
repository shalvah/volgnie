require 'bundler/setup'
require_relative './bootstrap'
require_relative './app/purge/purger'
require_relative './app/purge/preparer'
require_relative './app/purge/cleaner'

# Idempotent. If this function fails midway, simply retry.
def start_purge(event:, context:)
  payload = get_sns_payload event
  preparer = Purge::Preparer.build(payload["user"])
  preparer.save_following
  followers = preparer.fetch_followers
  Events.purge_ready(followers, payload["user"], payload["purge_config"])
end

# Idempotent. If this function fails midway, simply retry.
def purge_followers(event:, context:)
  payload = get_sns_payload event
  purger = Purge::Purger.build(payload["user"], payload["purge_config"]) { context.get_remaining_time_in_millis }
  purger.purge(payload["followers"])

  Events.purge_finish(payload["user"], payload["purge_config"])
end

# Idempotent. If this function fails midway, simply retry.
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