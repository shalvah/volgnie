
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

      @creds = get_user_creds(user["id"], cache)
      @t = twitter.as_user(@creds["token"], @creds["secret"])
    end

    def purge(followers)
      last_processed = {}
      begin
        followers.each_with_index do |follower, index|
          break_if_out_of_time
          last_processed = { id: purge_if_failing(follower), index: index }
        end
      rescue StandardError => e
        wrapped = e.is_a?(ErrorDuringPurge) ? e : ErrorDuringPurge.new(e)
        wrapped.last_processed = last_processed
        wrapped.processing_for = @user
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