require 'json'

def handler
  user_twitter_creds = get_user_twitter_creds
  user_config = get_user_config

  following = get_following(user_twitter_creds)
  store_following(following)

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

def purge_batch
  followers.each do |follower|
    next if (user.is_following(follower))

    next if user.has_interacted_with(follower)

    # Intentionally synchronous? to take adv of rate limits
    block_user(follower)
    unblock_user(follower)
    record_removal(follower, user)
  end

  record_batch_processed
  if is_last_batch && batches_complete
    dispatch_event(:purge_finish, user)
  end
end

def finish_purge
  purged_users = fetch_purged_users(user)
  send_email_report(user, purged_users)
  report_metrics
  clear_users_data(user)
end