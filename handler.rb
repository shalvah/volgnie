require 'bundler/setup'
require_relative './app/bootstrap'
require_relative './app/purge/purger'
require_relative './app/purge/preparer'
require_relative './app/purge/cleaner'

at_exit { flush_traces }

# Idempotent. If this function fails midway, simply retry.
def start_purge(event:, context:)
  payload = get_sns_payload event
  lambda_transaction(context, payload) do

    preparer = Purge::Preparer.build(payload["user"])
    preparer.save_following
    followers = preparer.fetch_followers
    Events.purge_ready(followers, payload["user"], payload["purge_config"])
  end
end

# Idempotent. If this function fails midway, simply retry.
def purge_followers(event:, context:)
  payload = get_sns_payload event
  lambda_transaction(context, payload) do |span|

    purger = Purge::Purger.build(payload["user"], payload["purge_config"])
    purger.purge_next_batch(payload["followers"])

    Events.purge_finish(payload["user"], payload["purge_config"])
  rescue Purge::DoneWithBatch
    # Don't count this as a failure
    span.set_attribute("purge.break", 1)
    span.finish
    raise
  end
end

# Idempotent. If this function fails midway, simply retry.
def finish_purge(event:, context:)
  payload = get_sns_payload event
  lambda_transaction(context, payload) do

    cleaner = Purge::Cleaner.build(payload["user"], payload["purge_config"])
    cleaner.clean
  end
end

# Only meant for direct invocation, to test a specific piece of functionality
def sanities(event:, context:)
  Honeybadger.configure { |h| h.report_data = false }
  lambda_transaction(context) do
    require_relative "./sanities/#{event}"
  end
end