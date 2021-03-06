require_relative '../../app/purge/cleaner'

RSpec.describe "Purge::Cleaner" do
  let(:mock_redis) { MockRedis.new }
  let(:followers_count) { 9 }
  let(:user) { build(:user, :with_ff, followers_count: followers_count) }
  let(:purged_followers) {
    Faker::Number.unique.clear
    failing_follower_indices = Faker::Number.within(range: 1...followers_count).to_i.times.map do
      Faker::Number.unique.within(range: 0...followers_count).to_i
    end
    user[:followers].filter.with_index { |val, index| failing_follower_indices.include?(index) }
  }
  let(:payload) {
    {
      "user" => {
        "id" => user[:id],
        "following_count" => user[:following].size,
        "followers_count" => user[:followers].size,
        "username" => user[:username],
      },
      "purge_config" => {
        "report_email" => "purge_here@volgnie.com",
        "level" => 3,
        "__simulate" => true,
      }
    }
  }

  before do
    Mail::TestMailer.deliveries.clear
    mock_redis.sadd("purged-followers-#{user[:id]}", purged_followers.map(&:to_json))

    cleaner = Purge::Cleaner.new(payload["user"], payload["purge_config"], mock_redis, Aws::CloudWatch::Client.new)
    cleaner.clean
  end

  it "sends email report and removes user data" do
    expect(Mail::TestMailer.deliveries).to_not be_empty
    expect(Mail::TestMailer.deliveries).to include(an_object_satisfying do |mail|
      AppConfig[:mail][:from].end_with?("<#{mail.from[0]}>") && mail.to == [payload["purge_config"]["report_email"]]
    end)
    expect(mock_redis.smembers("purged-followers-#{user[:id]}")).to be_empty
  end
end