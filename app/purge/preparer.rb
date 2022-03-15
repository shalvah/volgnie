
require_relative "./errors"

module Purge
  # The Preparer gets things ready for the purge. It:
  # - fetches the user's following and saves in Redis
  # - fetches the user's followers (up to the specified limit) and returns, along with the user and purge config
  class Preparer

    def self.build(user, follower_limit = ::AppConfig[:default_follower_limit])
      new(user, Services[:twitter], Services[:cache], follower_limit)
    end


    def initialize(user, twitter, cache, follower_limit = ::AppConfig[:default_follower_limit])
      @cache = cache
      @follower_limit = follower_limit

      @user = AppUser.from(user)
      @t = get_twitter_client(twitter, @user.id, cache)
    end

    def save_following
      return if @cache.exists("following-#{@user.id}") == 1

      following = @t.get_following(@user.id, {all: true})
      @cache.set("following-#{@user.id}", following.to_json, ex: TWO_DAYS)
    end

    def fetch_followers
      followers = []
      @t.get_followers(@user.id, @follower_limit, chunked: true) do |followers_set, meta|
        followers += followers_set
        throw :stop_chunks if followers.size >= @follower_limit
      end
      followers
    end

  end

end