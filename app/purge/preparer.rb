
require_relative "./errors"

module Purge

  class Preparer
    DEFAULT_FOLLOWER_LIMIT = 5000

    def self.build(payload, follower_limit = DEFAULT_FOLLOWER_LIMIT)
      new(payload, Twitter, Cache, follower_limit)
    end


    def initialize(payload, twitter, cache, follower_limit = DEFAULT_FOLLOWER_LIMIT)
      @payload = payload
      @cache = cache
      @follower_limit = follower_limit

      @t = get_twitter_client(twitter, payload["user"], cache)
      @user = payload["user"]
    end

    def prepare
      save_following
      [fetch_followers, @user, @payload["purge_config"]]
    end

    private

    def save_following
      following = @t.get_following(@user["id"], all: true)
      @cache.set("following-#{@user["id"]}", following.to_json, ex: TWO_DAYS)
    end

    def fetch_followers
      followers = []
      @t.get_followers(@user["id"], chunked: true) do |followers_set, meta|
        followers += followers_set
        throw :stop_chunks if followers.size >= @follower_limit
      end
      followers
    end

  end

end