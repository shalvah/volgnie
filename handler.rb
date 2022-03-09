require 'bundler/setup'
require_relative './app/bootstrap'
require_relative './app/purge/purger'
require_relative './app/purge/preparer'
require_relative './app/purge/cleaner'

at_exit { defined?(OTelProcessor) && OTelProcessor.shutdown(timeout: 10) }

# Idempotent. If this function fails midway, simply retry.
def start_purge(event:, context:)
  payload = get_sns_payload event
  set_context_data(context, payload["user"])

  preparer = Purge::Preparer.build(payload["user"])
  preparer.save_following
  followers = preparer.fetch_followers
  Events.purge_ready(followers, payload["user"], payload["purge_config"])
end

# Idempotent. If this function fails midway, simply retry.
def purge_followers(event:, context:)
  payload = get_sns_payload event
  set_context_data(context, payload["user"])

  purger = Purge::Purger.build(payload["user"], payload["purge_config"])
  purger.purge_next_batch(payload["followers"])

  Events.purge_finish(payload["user"], payload["purge_config"])
end

# Idempotent. If this function fails midway, simply retry.
def finish_purge(event:, context:)
  payload = get_sns_payload event
  set_context_data(context, payload["user"])

  cleaner = Purge::Cleaner.build(payload["user"], payload["purge_config"])
  cleaner.clean
end

# Only meant for direct invocation, to test a specific piece of functionality
def sanities(event:, context:)
  Honeybadger.configure { |h| h.report_data = false }
  require_relative "./sanities/#{event}"
end