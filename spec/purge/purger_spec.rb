require_relative '../../app/purge/purger'

RSpec.describe "Purge::Purger", :focus do

  let(:mock_twitter) { double(TwitterApi) }
  let(:mock_redis) { MockRedis.new }
  let(:followers_count) { 9 }
  let(:user) { build(:user, :with_ff, followers_count: followers_count) }
  let(:criteria) { double(Purge::Criteria) }
  let(:failing_follower_indices) {
    Faker::Number.unique.clear
    Faker::Number.within(range: 1...followers_count).to_i.times.map do
      Faker::Number.unique.within(range: 0...followers_count).to_i
    end
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

  before(:each) do
    allow(mock_twitter).to receive(:as_user).and_return(mock_twitter)
    mock_redis.set("keys-#{user[:id]}", { token: "tokennn", secret: "secrettt" }.to_json)
    expect(criteria).to receive(:passes).at_most(followers_count).times do |follower|
      index = user[:followers].find_index { |f| f[:id] == follower[:id] }
      !failing_follower_indices.include?(index)
    end
  end

  it "runs purge as expected" do
    time_limit_proc = proc { Float::INFINITY }

    purger = Purge::Purger.new(payload["user"], criteria, mock_twitter, mock_redis, time_limit_proc, simulating: true)
    purger.purge user[:followers]

    purged = failing_follower_indices.map { |i| stringify_keys(user[:followers][i]) }
    actual_purged = mock_redis.lrange("purged-followers-#{user[:id]}", 0, -1).map { |u| JSON.parse(u) }
    expect(actual_purged).to contain_exactly *purged
  end

  it "stops if out of time" do
    time_limit_proc = double(Proc)
    allow(time_limit_proc).to receive(:call).and_return(100_000, 100_000, 4000, 100)

    expect do
      purger = Purge::Purger.new(payload["user"], criteria, mock_twitter, mock_redis, time_limit_proc, simulating: true)
      purger.purge user[:followers]
    end.to raise_error do |error|
      expect(error).to be_a(Purge::OutOfTime)
      expect(error.last_processed[:index]).to eq(2)
      expect(error.processing_for).to eq(AppUser.from(payload["user"]))
    end
  end
end