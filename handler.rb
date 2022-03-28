# frozen_string_literal: true

require 'bundler/setup'
require_relative './app/bootstrap'
require_relative './app/purge/purger'
require_relative './app/purge/preparer'
require_relative './app/purge/cleaner'

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
    span.set_attribute("purge.break", 1)

    # Serialize payload so we can resume
    time_to_resume = Time.now + AppConfig[:resume_batch_in_seconds] # Next batch in 5 minutes
    key = "purge-resume-#{time_to_resume.getutc.strftime("%Y%m%d%H%M")}"
    Services[:cache].sadd(key, payload.to_json)
  end
end

# Checks if there's a next batch of purges due, and triggers them
def push_next_batch(event:, context:)
  logger.info "Checking for batches to dispatch..."
  times = []
  time_end = Time.now
  time = time_end - (AppConfig[:resume_batch_in_seconds] + 60)
  times << (time += 60) while time < time_end
  keys = times.map { |t| "purge-resume-#{t.getutc.strftime("%Y%m%d%H%M")}" }

  payloads = Services[:cache].pipelined do |c|
    keys.map { |k| c.smembers(k) }
  end.flatten
  # In test, we delete before we dispatch (since we dispatch synchronously)
  env_is?("test") && Services[:cache].pipelined { |c| keys.map { |k| c.del(k) } }

  payloads.each do |payload|
    payload = JSON.parse(payload)
    Events.purge_ready(payload["followers"], payload["user"], payload["purge_config"])
  end

  env_is_not?("test") && (keys.map { |k| Services[:cache].del(k) })
  logger.info "Dispatched #{payloads.size} batches"
  payloads.size
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
  Honeybadger.configure { |h| h.report_data = false } unless event == "errors"
  lambda_transaction(context) do
    require_relative "./sanities/#{event}"
  end
end

def retry(event:, context:)
  full_name = "volgnie-dev-#{event["function"]}"
  count = event["count"] || 10000
  raise "Couldn't find any event data" unless Services[:cache].exists("purge-dlq-#{full_name}")
  events = Services[:cache].lpop("purge-dlq-#{full_name}", count)

  lambda_client = (ENV["IS_OFFLINE"] || ENV["IS_LOCAL"]) ?
    Aws::Lambda::Client.new({ endpoint: 'http://localhost:3002' })
    : Aws::Lambda::Client.new
  events.each do |original_event|
    lambda_client.invoke({
      function_name: full_name,
      invocation_type: "Event",
      payload: {
        "Records" => [
          { "Sns" => { "Message" => original_event } }
        ]
      }.to_json
    })
  end
  events.size
end