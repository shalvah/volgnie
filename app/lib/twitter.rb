# frozen_string_literal: true

require "rest-client"
require "oauth"
require "oauth/request_proxy/rest_client_request"

class OAuth::RequestProxy::RestClient::Request
  # TODO PR this patch
  # Post params should only be included in the signature for form-data
  # But Rest-Client requires you to encode JSON as string, so it's impossible to know
  def post_parameters
    # Post params are only used if posting form data
    is_form_data = request.payload && request.payload.headers['Content-Type'] == 'application/x-www-form-urlencoded'
    if is_form_data && (method == "POST" || method == "PUT")
      OAuth::Helper.stringify_keys(query_string_to_hash(request.payload.to_s) || {})
    else
      {}
    end
  end
end

class TwitterApi
  DEFAULT_TIMEOUT = 20
  attr_accessor :access_token
  attr_accessor :access_token_secret

  def initialize(consumer_key = nil, consumer_secret = nil)
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

  def raw_request(name, method, endpoint, params = {}, body: {})
    Honeybadger.add_breadcrumb("Twitter API: #{name}", metadata: {
      endpoint: endpoint,
      params: params,
      method: method,
    }, category: "request")

    uri = @base_url + endpoint

    if body.empty?
      req = RestClient::Request.new(
        method: method, url: uri,
        headers: { params: params },
        timeout: 30
      )
    else
      req = RestClient::Request.new(
        method: method, url: uri,
        headers: { params: params, content_type: :json },
        payload: body.to_json,
        timeout: 30
      )
    end
    req = with_user_auth(req, uri)
    response = req.execute

    JSON.parse(response.body)
  rescue RestClient::Exception => e
    current_span = OpenTelemetry::Trace.current_span
    current_span.set_attribute("http.response_body", e.http_body)
    Honeybadger.context({"http.response_body": e.http_body })
    raise
  end

  def request(name, method, endpoint, query_params = {}, body: {}, options: {}, &block)
    tracer = OpenTelemetry.tracer_provider.tracer('custom')
    tracer.in_span(
      "Twitter API: #{name}", kind: :client,
      attributes: { "http.endpoint" => endpoint, "http.options" => options.to_json },
    ) do

      response = raw_request(name, method, endpoint, query_params, body: body)
      data = response["data"]

      if options[:all]
        pagination_token = response["meta"]["next_token"]
        while pagination_token
          query_params["pagination_token"] = pagination_token
          response = raw_request(name, method, endpoint, query_params, body: body)
          data += response["data"]
          pagination_token = response["meta"]["next_token"]
        end
      end

      if options[:chunked]
        catch(:stop_chunks) do
          block.call(data, response["meta"])
          pagination_token = response["meta"]["next_token"]
          while pagination_token
            query_params["pagination_token"] = pagination_token
            response = raw_request(name, method, endpoint, query_params, body: body)
            block.call(response["data"], response["meta"])
            pagination_token = response["meta"]["next_token"]
          end
        end
        return
      end

      data
    end
  end

  def get_user(id)
    endpoint = "/users/#{id}"
    query_params = { "user.fields" => "id,name,profile_image_url,protected,public_metrics,username" }
    TwitterUser.new(**request(:get_user, :get, endpoint, query_params))
  end

  def get_following(id, options = {}, &block)
    endpoint = "/users/#{id}/following"
    query_params = { max_results: 1000 }
    request(:get_following, :get, endpoint, query_params, options: options, &block)
  end

  def get_followers(id, options = {}, &block)
    endpoint = "/users/#{id}/followers"
    query_params = { max_results: 1000 }
    request(:get_followers, :get, endpoint, query_params, options: options, &block)
  end

  def block(source_user_id, target_user_id)
    endpoint = "/users/#{source_user_id}/blocking"
    request(:block, :post, endpoint, body: {
      target_user_id: target_user_id
    })
  rescue RestClient::BadRequest => e
    response = JSON.parse(e.http_body)
    return true if response["errors"][0]["message"] == "You cannot block an account that is not active."
    raise
  end

  def unblock(source_user_id, target_user_id)
    endpoint = "/users/#{source_user_id}/blocking/#{target_user_id}"
    request(:unblock, :delete, endpoint)
  rescue RestClient::BadRequest => e
    response = JSON.parse(e.http_body)
    return true if response["errors"][0]["message"] == "You cannot unblock an account that is not active."
    raise
  end
end

Services.register(:twitter) do
  TwitterApi.new(
    ENV.fetch('TWITTER_API_KEY'),
    ENV.fetch('TWITTER_API_KEY_SECRET'),
  )
end