require_relative './relationship_checker'
require_relative "./errors"

module Purge

  class Criteria
    MUTUAL = 4
    MUST_HAVE_REPLIED_TO = 3
    MUST_HAVE_INTERACTED = 2

    def self.build(user, following, purge_config)
      new(purge_config, Services[:relationship_checker].build(user, following))
    end

    def initialize(purge_config, relationship_checker)
      @config = PurgeConfig.from(purge_config)
      @rc = relationship_checker
    end

    def check_batch(followers)
      this_user = @rc
      mutuals = followers.map { |f| this_user.is_following(f) }

      return mutuals if @config.level == MUTUAL

      to_fetch = followers.zip(mutuals).flat_map { |f, is_mutual| is_mutual ? [] : [f] }
      return mutuals if to_fetch.empty?

      results = case @config.level
        when MUST_HAVE_REPLIED_TO
          this_user.has_replied_to_follower_bulk(to_fetch)
        when MUST_HAVE_INTERACTED
          this_user.has_replied_or_been_replied_to_bulk(to_fetch)
      end

      # Merge results
      results_iter = results.each
      mutuals.map { |is_mutual| is_mutual || results_iter.next }
    end

    def self.to_text(level)
      {
        MUST_HAVE_REPLIED_TO => "Keep followers that I've replied to in the past 90 days",
        MUST_HAVE_INTERACTED => "Keep followers that I've replied to or have replied to me in the past 90 days",
        MUTUAL => "Keep followers that I'm also following (\"mutuals\")",
      }[level]
    end
  end
end