require 'date'
require_relative "./errors"
require_relative "../lib/aws"

module Purge

  class RelationshipChecker
    def self.build(user, following)
      new(user, following, Services[:lambda_client])
    end

    def initialize(user, following, lambda_client, days_ago = 90)
      @user = AppUser.from(user)
      @following = following
      @lambda_client = lambda_client
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
        query: query,
        checkExistenceOnly: true
      }
      response = @lambda_client.invoke({
        function_name: "volgnie-dev-search_twitter",
        invocation_type: "RequestResponse",
        payload: { body: payload }.to_json,
      })

      # Docs say it's a String, but it seems to be returning a StringIO
      result = JSON.parse(response.payload.is_a?(StringIO) ? response.payload.string : response.payload)
      raise_if_search_failed(result, query)
      result["exists"]
    end

    def raise_if_search_failed(result, query)
      if result["errorMessage"]
        Honeybadger.context({ query: query })
        raise SearchHandlerFailed.new(
          "Search handler returned an error: #{result["errorType"]} - #{result["errorMessage"]}.\nTrace: #{result["trace"]}"
        )
      end
    end
  end
end