require_relative "./errors"
require_relative "./criteria"

module Purge

  class Purger
    MINIMUM_PURGE_TIME_MS = 500

    def self.build(user_hash, purge_config)
      following = JSON.parse(Services[:cache].get("following-#{user_hash["id"]}"))
      criteria = Criteria.build(user_hash, following, purge_config)
      new(
        user_hash, criteria, Services[:twitter], Services[:cache], simulating: purge_config["__simulate"]
      )
    end

    def initialize(user, purge_criteria, twitter, cache, simulating:, batch_size: 10)
      @user = AppUser.from(user)
      @criteria = purge_criteria
      @cache = cache
      @simulating = simulating
      @batch_size = batch_size

      @creds = get_user_creds(@user.id, @cache)
      @t = twitter.as_user(@creds["token"], @creds["secret"])
    end

    def purge_next_batch(followers)
      batches_processed = @cache.get("purge-#{@user.id}-batches-processed")
      batches_processed = batches_processed ? Integer(batches_processed) : 0

      batch = followers.drop(batches_processed * @batch_size).each_slice(@batch_size).first
      return true unless batch

      Honeybadger.context({
        user: @user.to_json,
        batches_processed: batches_processed,
        batch_real_size: batch.size,
        total_size: followers.size,
      })
      statuses = @criteria.check_batch(batch)
      followers_to_remove = batch.zip(statuses).flat_map do |follower, should_keep|
        should_keep ? [] : [follower]
      end
      followers_to_remove.map { |f| remove_follower(f) }

      @cache.set("purge-#{@user.id}-batches-processed", batches_processed + 1, ex: TWO_DAYS)

      raise DoneWithBatch # Trigger retry for the next batch
    end

    def remove_follower(follower)
      unless @simulating
        @t.block(@user.id, follower["id"]) # Intentionally synchronous calls to prolong rate limits
        @t.unblock(@user.id, follower["id"])
      end

      # If we're interrupted mid-batch, we might process some users twice, so we use a set
      @cache.sadd("purged-followers-#{@user.id}", follower.to_json)

      follower["id"]
    end

  end
end