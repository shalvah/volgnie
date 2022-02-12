require_relative '../app/web'
require 'rack/test'

user = {
  "username" => "theshalvah",
  "name" => "jukai (樹海)",
  "id" => "876342319217332225",
  "public_metrics" => {
    "followers_count" => 7354,
    "following_count" => 138,
    "tweet_count" => 43875,
    "listed_count" => 62
  },
  "profile_image_url" => "https://pbs.twimg.com/profile_images/1348334243898945536/1r1J6_vE_normal.jpg",
  "protected" => false
}

RSpec.describe "Web UI" do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  describe "/purge/start" do

    email = "test@volgnie.com"
    payload = {
      user: {
        id: user["id"],
        following_count: user["public_metrics"]["following_count"],
        followers_count: user["public_metrics"]["followers_count"],
        username: user["username"],
      },
      purge_config: {
        report_email: email,
        level: 2,
        __simulate: false,
      }
    }

    before(:each) do
      env "rack.session", { user: user }
      Services[:dispatcher].clear
      Services[:cache].flushall
    end

    it "fires purge_start event" do
      post "/purge/start?email=#{email}&level=2"
      expect(Services[:dispatcher].dispatched).to match_array([expected_event(payload)])
    end

    it "will not fire purge_start event if already running" do
      AppConfig.set(:purge_lock_duration, 1)

      post "/purge/start?email=#{email}&level=2"
      expect(Services[:dispatcher].dispatched).to match_array([expected_event(payload)])
      post "/purge/start?email=#{email}&level=2"
      expect(Services[:dispatcher].dispatched).to match_array([expected_event(payload)])
      sleep 1
      post "/purge/start?email=#{email}&level=2"
      expect(Services[:dispatcher].dispatched).to match_array([expected_event(payload), expected_event(payload)])
    end
  end
end

def expected_event(payload)
    {
      event: :purge_start,
      payload: {
        user: payload[:user],
        purge_config: a_hash_including(payload[:purge_config])
      }
    }
end