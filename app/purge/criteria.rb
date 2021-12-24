require_relative './relationship_checker'
require_relative "./errors"

module Purge

  class Criteria
    MUTUAL = 4
    MUST_HAVE_REPLIED_TO = 3
    MUST_HAVE_INTERACTED = 2

    def self.build(user, purge_config)
      new(user, purge_config, RelationshipChecker.build(user))
    end

    def initialize(user, purge_config, relationship_checker)
      @user = user
      @config = purge_config
      @rc = relationship_checker
    end

    def passes(follower)
      case @config["level"]
      when MUTUAL
        @rc.is_following(follower)
      when MUST_HAVE_REPLIED_TO
        @rc.is_following(follower) || @rc.has_replied_to_follower(follower)
      when MUST_HAVE_INTERACTED
        @rc.is_following(follower) || @rc.has_replied_or_been_replied_to(follower)
      end
    end

    def self.to_text(level)
      {
        MUST_HAVE_REPLIED_TO => "Keep only those followers that I've replied to in the past 90 days",
        MUST_HAVE_INTERACTED => "Keep only those followers that I've replied to or have replied to me in the past 90 days",
        MUTUAL => "Keep only those followers that I'm also following (\"mutuals\")",
      }[level]
    end
  end
end