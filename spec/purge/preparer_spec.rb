require_relative '../../app/purge/preparer'

RSpec.describe "Purge::Purger" do
  it "fetches data needed for purge" do
    user = build(:user, :with_ff, followers_count: 11)
    payload = {
      "user" => {
        "id" => user[:id],
        "following_count" => user[:following].size,
        "followers_count" => user[:followers].size,
        "username" => user[:username],
      },
      "purge_config" => {
        "report_email" => "purge_here@volgnie.com",
        "level" => 3,
      }
    }

    mock_twitter = double(TwitterApi)
    allow(mock_twitter).to receive(:as_user).and_return(mock_twitter)
    expect(mock_twitter).to(receive(:get_following)) { |id| user[:following] }
    expect(mock_twitter).to receive(:get_followers) do |id, options = {}, &block|
      catch(:stop_chunks) { user[:followers].each_slice(3) { |chunk| block.call(chunk, {}) } }
    end
    mock_redis = MockRedis.new
    mock_redis.set("keys-#{user[:id]}", {token: "tokennn", secret: "secrettt"}.to_json)

    preparer = Purge::Preparer.new(payload, mock_twitter, mock_redis, 9)

    expect(preparer.prepare).to match([
      user[:followers][0..8], payload["user"], payload["purge_config"]
    ])
    expect(mock_redis.get("following-#{user[:id]}")).to match user[:following].to_json
  end
end