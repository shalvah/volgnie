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
      @config = purge_config
      @rc = relationship_checker
    end

    def passes(follower)
      this_user = @rc
      case @config["level"]
      when MUTUAL
        this_user.is_following(follower)
      when MUST_HAVE_REPLIED_TO
        this_user.is_following(follower) || this_user.has_replied_to_follower(follower)
      when MUST_HAVE_INTERACTED
        this_user.is_following(follower) || this_user.has_replied_or_been_replied_to(follower)
      end
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