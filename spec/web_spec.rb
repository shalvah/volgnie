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
    expected_event = { event: "purge_start", payload: payload }

    before(:each) do
      env "rack.session", { user: user }
      Events.__clear_dispatched
      Cache.flushall
    end

    it "fires purge_start event" do
      post "/purge/start?email=#{email}"
      expect(Events.__dispatched).to match([expected_event])
    end

    it "will not fire purge_start event if already running" do
      Config::PurgeLockDuration = 1

      post "/purge/start?email=#{email}"
      expect(Events.__dispatched).to match([expected_event])
      post "/purge/start?email=#{email}"
      expect(Events.__dispatched).to match([expected_event])
      sleep 1
      post "/purge/start?email=#{email}"
      expect(Events.__dispatched).to match([expected_event, expected_event])
    end
  end
end