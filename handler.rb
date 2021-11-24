require 'json'

def index(event:, context:)
  {
    statusCode: 200,
    headers: {
      'cache-control': 'no-cache, no-store, must-revalidate, max-age=0, s-maxage=0',
      'content-type': 'text/html; charset=utf8'
    },
    body: {
      message: 'Go Serverless v1.0! Your function executed successfully!',
      input: event
    }.to_json
  }
end

def handler
  user_twitter_creds = get_user_twitter_creds
  user_config = get_user_config

  following = get_following(user_twitter_creds)
  store_following(following)

  get_followers_chunks(user_twitter_creds).each do |followers_set|
    # race condition, atomicity
    dispatch_event(:check_followers, followers_set)
  end

  {
    statusCode: 200,
    headers: {
      'cache-control': 'no-cache, no-store, must-revalidate, max-age=0, s-maxage=0',
      'content-type': 'text/html; charset=utf8'
    },
    body: "Hi"
  }
end

def check_followers
  followers.each do |follower|
    next if (user.is_following(follower))

    next if user.has_interacted_with(follower)

    # Intentionally synchronous? to take adv of rate limits
    block_user(follower)
    unblock_user(follower)
    record_removal(follower, user)
  end

  send_email_if_last_batch
  clear_users_data
end