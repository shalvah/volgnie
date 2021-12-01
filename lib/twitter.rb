# frozen_string_literal: true

require 'rest-client'
require "oauth"
require "oauth/request_proxy/rest_client_request"

class TwitterApi
  DEFAULT_TIMEOUT = 20
  attr_accessor :access_token
  attr_accessor :access_token_secret

  def initialize(consumer_key, consumer_secret)
    @consumer_key = consumer_key
    @consumer_secret = consumer_secret

    @base_url = "https://api.twitter.com/2"
  end

  def as_user(access_token, access_token_secret)
    in_user_context = self.dup
    in_user_context.access_token = access_token
    in_user_context.access_token_secret = access_token_secret
    in_user_context
  end

  def with_user_auth(req, uri)
    oauth_consumer = OAuth::Consumer.new(@consumer_key, @consumer_secret, site: 'https://api.twitter.com')
    access_token = OAuth::AccessToken.from_hash(oauth_consumer, {
      oauth_token: @access_token,
      oauth_token_secret: @access_token_secret,
    })
    oauth_params = { consumer: oauth_consumer, token: access_token }

    oauth_helper = OAuth::Client::Helper.new(req, oauth_params.merge(request_uri: uri))
    req.headers["Authorization"] = oauth_helper.header
    req.processed_headers["authorization"] = oauth_helper.header
    req
  end

  def raw_request(method, endpoint, params = {}, body: {})
    uri = @base_url + endpoint
    req = RestClient::Request.new(
      method: method,
      url: uri,
      headers: { params: params, content_type: :json },
      body: body,
      timeout: 30
    )
    req = with_user_auth(req, uri)
    response = req.execute

    JSON.parse(response.body)
  end

  def request(method, endpoint, params = {}, body: {}, options: {}, &block)
    body = raw_request(method, endpoint, params, body: body)
    data = body["data"]

    if options[:all]
      pagination_token = body["meta"]["next_token"]
      while pagination_token
        params["pagination_token"] = pagination_token
        body = raw_request(method, endpoint, params, body: body)
        data += body["data"]
        pagination_token = body["meta"]["next_token"]
      end
      require 'ray'; ray data;
      return data
    end

    if options[:chunked]
      block.call(data, body["meta"])
      pagination_token = body["meta"]["next_token"]
      while pagination_token
        params["pagination_token"] = pagination_token
        body = raw_request(method, endpoint, params, body: body)
        block.call(body["data"], body["meta"])
        pagination_token = body["meta"]["next_token"]
      end
      return
    end

    data
  end

  def get_user(id)
    endpoint = "/users/#{id}"
    query_params = { "user.fields" => "id,name,profile_image_url,protected,public_metrics,username" }
    request(:get, endpoint, query_params)
  end

  def get_following(id, options = {}, &block)
    endpoint = "/users/#{id}/following"
    query_params = { max_results: 1000 }
    request(:get, endpoint, query_params, options: options, &block)
  end

  def get_followers(id, options = {}, &block)
    endpoint = "/users/#{id}/followers"
    query_params = { max_results: 1000 }
    request(:get, endpoint, query_params, options: options, &block)
  end

  def block_user(source_user_id, target_user_id)
    endpoint = "/users/#{source_user_id}/blocking}"
    request(:post, endpoint, body: {
      target_user_id: target_user_id
    })
  end

  def unblock_user(source_user_id, target_user_id)
    endpoint = "/users/#{source_user_id}/blocking/#{target_user_id}"
    request(:delete, endpoint)
  end

  def fetch_interactions(source_user, target_user)
    endpoint = "/tweets/search/recent"
    since = "2021-08-20"
    query = "((from:#{source_user} to:#{target_user}) OR (from:#{target_user} to:#{source_user})) since:#{since}"
  end
end

Twitter = TwitterApi.new(
  ENV.fetch('TWITTER_API_KEY'),
  ENV.fetch('TWITTER_API_KEY_SECRET'),
)