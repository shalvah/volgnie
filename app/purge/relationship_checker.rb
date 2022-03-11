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
      @following.find { |f| f["id"] == follower["id"] }
    end

    def has_replied_to_follower_bulk(followers)
      date = since_date
      queries = followers.map do |f|
        "from:#{@user.username} to:#{f["username"]} since:#{date}"
      end
      query_tweets_exist?(queries)
    end

    def has_replied_or_been_replied_to_bulk(followers)
      date = since_date
      queries = followers.map do |f|
        "((from:#{@user.username} to:#{f["username"]}) OR (from:#{f["username"]} to:#{@user.username})) since:#{date}"
      end
      query_tweets_exist?(queries)
    end

    def since_date
      (Date.today - @days_ago).to_s
    end

    def query_tweets_exist?(queries)
      payload = {
        queries: queries,
        checkExistenceOnly: true
      }

      Honeybadger.context({ searchQuery: queries.to_json })
      tracer = OpenTelemetry.tracer_provider.tracer('custom')
      result = tracer.in_span(
        "Zearch API",
        attributes: { "queries" => queries },
        kind: :client
      ) do |span|
        req = RestClient::Request.new(
          method: "post",
          url: ENV["ZEARCH_ENDPOINT"],
          headers: { authorization: ENV["ZEARCH_KEY"], content_type: :json },
          payload: payload.to_json,
          timeout: 30
        )
        response = req.execute
        span.set_attribute("http.response_body", response.body)
        JSON.parse(response.body)
      end

      result["exists"]
    end
  end
end