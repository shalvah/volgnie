
require 'bundler/setup'
require_relative './app/helpers'
require_relative './lib/cache'
require_relative './lib/sns'
require_relative './lib/twitter'


def start_purge(event:, context:)
  payload = get_sns_payload event
  user = payload["user"]
  creds = JSON.parse(Cache.get("keys-#{user["id"]}"))
  purge_config = payload["purge_config"]

  # todo paginate, iterate, save
  following = Twitter.as_user(creds["token"], creds["secret"]).get_following(user["id"])["data"]
  p Cache.set("following-#{user["id"]}", following.to_json, ex: TWO_DAYS)
  exit


  batches_dispatched = 0
  complete = false
  begin
    get_followers_chunks(user_twitter_creds, user).each do |followers_set|
      # race condition, atomicity
      dispatch_event(:followers_batch, followers_set)
      batches_dispatched += 1
    end
    complete = true
  ensure
    record_expected_batches(batches_dispatched, complete)
  end
end

def purge_batch(event:, context:)
  followers = event
  followers.each do |follower|
    next if (user.is_following(follower))

    next if user.has_interacted_with(follower)

    # Intentionally synchronous? to hit rate limits slower
    block_user(follower)
    unblock_user(follower)
    record_removal(follower, user)
  end

  record_batch_processed
  if is_last_batch && batches_complete
    dispatch_event(:purge_finish, user)
  end
end

def finish_purge(event:, context:)
  purged_users = fetch_purged_users(user)
  send_email_report(user, purged_users)
  report_metrics
  clear_users_data(user)
end

def get_sns_payload(event)
  JSON.parse(event["Records"][0]["Sns"]["Message"])
end