require_relative './relationship_checker'

module Purge

  class Criteria
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
      when 4
        @rc.is_following(follower)
      when 3
        @rc.is_following(follower) || @rc.has_replied_to_follower(follower)
      when 2
        @rc.is_following(follower) || @rc.has_replied_or_been_replied_to(follower)
      end
    end

  end
end