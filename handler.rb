
require 'bundler/setup'
require_relative './app/helpers'
require_relative './app/events'
require_relative './lib/cache'
require_relative './lib/twitter'


def start_purge(event:, context:)
  payload = get_sns_payload event
  user = payload["user"]
  creds = get_user_creds(user["id"])
  purge_config = payload["purge_config"]

  t = Twitter.as_user(creds["token"], creds["secret"])
  following = t.get_following(user["id"], all: true)
  Cache.set("following-#{user["id"]}", following.to_json, ex: TWO_DAYS)

  batches_dispatched = 0
  complete = false
  begin
    t.get_followers(user["id"], chunked: true) do |followers_set, meta|
      Events.new_batch(followers_set, user, purge_config)
      Cache.set("pagination-followers-#{user["id"]}", meta.to_json, ex: TWO_DAYS)
      batches_dispatched += 1
    end
    complete = true
  ensure
    Cache.set("batches-followers-#{user["id"]}", {dispatched: batches_dispatched, complete: complete}.to_json, ex: TWO_DAYS)
  end
end

def purge_batch(event:, context:)
  followers = get_sns_payload event
  creds = get_user_creds(user["id"])

  followers.each do |follower|
    t = Twitter.as_user(creds["token"], creds["secret"])
    next if (user.is_following(follower))

    next if user.has_interacted_with(follower)

    # Intentionally synchronous? to hit rate limits slower
    t.block_user(user, follower)
    t.unblock_user(user, follower)
    record_removal(follower, user)
  end

  record_batch_processed
  if is_last_batch && batches_complete
    dispatch_event(:purge_finish, user)
  end
end

def finish_purge(event:, context:)
  event = get_sns_payload event
  purged_users = fetch_purged_users(user)
  send_email_report(user, purged_users)
  report_metrics
  clear_users_data(user)
end