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

  def request(method, endpoint, params = {})
    uri = @base_url + endpoint
    req = RestClient::Request.new(
      method: method,
      url: uri,
      headers: {params: params},
      timeout: 30
    )
    req = with_user_auth(req, uri)
    response = req.execute

    JSON.parse(response.body)
  end

  def get_user(id)
    endpoint = "/users/#{id}"
    query_params = {"user.fields" => "id,name,profile_image_url,protected,public_metrics,username"}
    request(:get, endpoint, query_params)
  end

  def get_following(id)
    endpoint = "/users/#{id}/following"
    query_params = {max_results: 1000}
    request(:get, endpoint, query_params)
  end
end

Twitter = TwitterApi.new(
  ENV.fetch('TWITTER_API_KEY'),
  ENV.fetch('TWITTER_API_KEY_SECRET'),
)