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
    expected_event = {
      event: :purge_start,
      payload: {
        user: AppUser.from({
          id: user["id"],
          following_count: user["public_metrics"]["following_count"],
          followers_count: user["public_metrics"]["followers_count"],
          username: user["username"],
        }),
        purge_config: PurgeConfig.from({
          report_email: email,
          level: 2,
          __simulate: false,
        })
      }
    }

    before(:each) do
      env "rack.session", { user: TwitterUser.new(**user) }
      Services[:dispatcher].clear
      Services[:cache].flushall
    end

    it "fires purge_start event" do
      post "/purge/start?email=#{email}&level=2"
      # A bit hacky, but it'll do
      expected_event[:payload][:purge_config][:trigger_time] = Services[:dispatcher].dispatched[0][:payload][:purge_config].trigger_time
      expect(Services[:dispatcher].dispatched).to match_array([expected_event])
    end
  end
end