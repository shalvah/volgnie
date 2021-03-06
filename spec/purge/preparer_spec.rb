require_relative '../../app/purge/preparer'

RSpec.describe "Purge::Preparer" do
  let!(:mock_twitter) { double(TwitterApi) }
  let!(:mock_redis) { MockRedis.new }
  let!(:user) { build(:user, :with_ff, followers_count: 11) }
  let(:user_payload) { {
    "id" => user[:id],
    "following_count" => user[:following].size,
    "followers_count" => user[:followers].size,
    "username" => user[:username],
  } }

  before do
    allow(mock_twitter).to receive(:as_user).and_return(mock_twitter)
    mock_redis.set("keys-#{user[:id]}", { token: "tokennn", secret: "secrettt" }.to_json)
  end

  it "fetches followers" do
    limit = 9
    expect(mock_twitter).to receive(:get_followers).and_return user[:followers].first(limit)

    preparer = Purge::Preparer.new(user_payload, mock_twitter, mock_redis, limit)

    expect(preparer.fetch_followers).to match(user[:followers][0..(limit -1)])
  end

  it "saves following" do
    expect(mock_twitter).to(receive(:get_following)) { |id| user[:following] }

    preparer = Purge::Preparer.new(user_payload, mock_twitter, mock_redis, 9)
    preparer.save_following

    expect(mock_redis.get("following-#{user[:id]}")).to match user[:following].to_json
  end
end