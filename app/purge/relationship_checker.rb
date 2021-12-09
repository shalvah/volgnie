module Purge

  require 'date'
  require_relative "../../lib/aws"

  class RelationshipChecker
    def build(user)
      lambda_client = ENV["IS_OFFLINE"] ? Aws::Lambda::Client.new({
        endpoint: 'http://localhost:3002'
      }) : Aws::Lambda::Client.new
      new(user, Cache, lambda_client)
    end

    def initialize(user, cache, lambda_client)
      @user = user
      @cache = cache
      @lambda_client = lambda_client
    end

    def is_following(follower)
      following.include? { |f| f["id"] === follower["id"] }
    end

    def has_replied_to_follower(follower, days_ago = 30)
      since = (Date.today - days_ago).to_s
      query = "((from:#{@user["username"]} to:#{follower["username"]}) OR (from:#{follower["username"]} to:#{@user["username"]})) since:#{since}"
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
      if result["errorMessage"]
        # Shouldn't notify twice?
        # Honeybadger.notify(result["errorMessage"], class_name: result["errorType"], backtrace: result["trace"])
      end

      result["exists"]
    end

    private

    def following
      @following ||= JSON.parse(@cache.get("following-#{@user["id"]}"))
    end
  end

end