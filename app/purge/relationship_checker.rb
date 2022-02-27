require 'date'
require_relative "./errors"
require_relative "../lib/aws"

module Purge

  class RelationshipChecker
    def self.build(user, following)
      new(user, following)
    end

    def initialize(user, following, days_ago = 90)
      @user = AppUser.from(user)
      @following = following
      @days_ago = days_ago
    end

    def is_following(follower)
      @following.find { |f| f["id"] === follower["id"] }
    end

    def has_replied_to_follower(follower)
      query = "from:#{@user.username} to:#{follower["username"]} since:#{since_date}"
      query_tweets_exist?(query)
    end

    def has_replied_or_been_replied_to(follower)
      query = "((from:#{@user.username} to:#{follower["username"]}) OR (from:#{follower["username"]} to:#{@user.username})) since:#{since_date}"
      query_tweets_exist?(query)
    end

    def since_date
      (Date.today - @days_ago).to_s
    end

    def query_tweets_exist?(query)
      payload = {
        queries: [query],
        checkExistenceOnly: true
      }

      Honeybadger.context({ searchQuery: payload.queries })

      req = RestClient::Request.new(
        method: "post",
        url: ENV["ZEARCH_ENDPOINT"],
        headers: { authorization: ENV["ZEARCH_KEY"], content_type: :json },
        body: payload,
        timeout: 30
      )
      response = req.execute

      result = JSON.parse(response.body)

      result["exists"]
    end
  end
end