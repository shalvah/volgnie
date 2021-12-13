require_relative '../../app/purge/cleaner'

RSpec.describe "Cleaner" do

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
        "report_email" => "purge_here@volgnie.xyz",
        "level" => 3,
        "__simulate" => true,
      }
    }
  }

  before do
    Mail::TestMailer.deliveries.clear
    mock_redis.lpush("purged-followers-#{user[:id]}", purged_followers.map(&:to_json))

    cleaner = Purge::Cleaner.new(payload["user"], payload["purge_config"], mock_redis, nil)
    cleaner.clean
  end

  it "sends email report" do
    expect(Mail::TestMailer.deliveries).to_not be_empty
    expect(Mail::TestMailer.deliveries).to include(an_object_satisfying do |mail|
      mail.from == [Config.mail[:from]] && mail.to == [payload["purge_config"]["report_email"]]
    end)
  end

  it "removes user data" do
    expect(mock_redis.lrange("purged-followers-#{user[:id]}", 0, -1)).to be_empty
  end
end