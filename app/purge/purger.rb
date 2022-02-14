require_relative "./errors"
require_relative "./criteria"

module Purge

  class Purger
    MINIMUM_PURGE_TIME_MS = 500

    def self.build(user_hash, purge_config, &time_limit_proc)
      following = JSON.parse(Services[:cache].get("following-#{user_hash["id"]}"))
      criteria = Criteria.build(user_hash, following, purge_config)
      new(
        user_hash, criteria, Services[:twitter], Services[:cache], time_limit_proc, simulating: purge_config["__simulate"]
      )
    end

    def initialize(user, purge_criteria, twitter, cache, time_limit_proc, simulating:)
      @user = AppUser.from(user)
      @criteria = purge_criteria
      @cache = cache
      @time_limit_proc = time_limit_proc
      @simulating = simulating

      @creds = get_user_creds(@user.id, @cache)
      @t = twitter.as_user(@creds["token"], @creds["secret"])
    end

    def purge(followers)
      last_processed = @cache.get("purge-last-processed-#{@user.id}")

      begin
        followers_to_purge = followers
        if last_processed
          last_index = followers.find_index { |f| f["id"] == last_processed }
          followers_to_purge = followers.drop(last_index + 1)
        end
        followers_to_purge.each_with_index do |follower, index|
          break_if_out_of_time
          last_processed = purge_if_failing(follower)
        end
        @cache.del("purge-last-processed-#{@user.id}", last_processed, ex: TWO_DAYS)
      rescue StandardError => e
        # If an error occurs, serialize state so we can resume
        @cache.set("purge-last-processed-#{@user.id}", last_processed, ex: TWO_DAYS) if last_processed
        wrapped = e.is_a?(ErrorDuringPurge) ? e : ErrorDuringPurge.new(e)
        unless ENV["APP_ENV"] == "test"
          Honeybadger.context({
            aws_request_id: context["aws_request_id"],
            user: payload["user"],
            last_processed: e.last_processed,
            total_size: payload["followers"].size,
          })
        end
        raise wrapped
      end
    end

    def purge_if_failing(follower)
      return follower["id"] if @criteria.passes(follower)

      unless @simulating
        @t.block(@user, follower) # Intentionally synchronous calls to prolong rate limits
        @t.unblock(@user, follower)
      end
      @cache.rpush("purged-followers-#{@user["id"]}", follower.to_json)

      follower["id"]
    end

    def break_if_out_of_time
      time_left = @time_limit_proc.call
      raise OutOfTime, "Time left (#{time_left}) is less than minimum time (#{MINIMUM_PURGE_TIME_MS})" if time_left < MINIMUM_PURGE_TIME_MS
    end

  end
end