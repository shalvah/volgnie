require_relative '../../app/purge/purger'

RSpec.describe "Purge::Purger" do
  let(:mock_twitter) { double(TwitterApi) }
  let(:mock_redis) { MockRedis.new }
  let(:followers_count) { 14 }
  let(:user) { build(:user, :with_ff, followers_count: followers_count) }
  let(:criteria) { double(Purge::Criteria) }
  let(:failing_follower_indices) { [1, 3, 4, 10, 6, 13] }
  let!(:failing_follower_ids) { failing_follower_indices.map { user[:followers][_1][:id] } }
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
    user[:followers] = user[:followers].map { |f| stringify_keys(f) }
    mock_redis.set("keys-#{user[:id]}", { token: "tokennn", secret: "secrettt" }.to_json)
    allow(mock_twitter).to receive(:as_user).and_return(mock_twitter)
    allow(criteria).to receive(:check_batch).thrice do |batch|
      batch.map { |f| !failing_follower_ids.include?(f["id"]) }
    end
  end

  batch_size = 5
  subject(:purger) {
    Purge::Purger.new(payload["user"], criteria, mock_twitter, mock_redis, batch_size: batch_size, simulating: true)
  }

  it "purges a batch as expected" do
    expect(criteria).to receive(:check_batch).once

    expect { purger.purge_next_batch user[:followers] }.to raise_error(Purge::DoneWithBatch)

    expect(batches_processed).to eq(1)
    first_batch_purged = expected_purged { _1 < batch_size }
    expect(actual_purged).to contain_exactly(*first_batch_purged)
  end

  it "is idempotent: can complete purge in batches" do
    expect(criteria).to receive(:check_batch).thrice

    # First run
    expect { purger.purge_next_batch user[:followers] }.to raise_error(Purge::DoneWithBatch)

    expect(batches_processed).to eq(1)
    first_batch_purged = expected_purged { _1 < batch_size }
    expect(actual_purged).to contain_exactly(*first_batch_purged)

    # Complete the purge
    2.times do
      expect { purger.purge_next_batch user[:followers] }.to raise_error(Purge::DoneWithBatch)
    end
    expect(batches_processed).to eq(3)
    expect(actual_purged).to contain_exactly *expected_purged

    # An extra run; nothing should change
    expect(purger.purge_next_batch user[:followers]).to eq(true)
    expect(batches_processed).to eq(3)
    expect(actual_purged).to contain_exactly *expected_purged
  end

  it "is idempotent: will retry batch if unexpected error happens" do
    expect(criteria).to receive(:check_batch).and_raise(RuntimeError)

    # First run
    expect { purger.purge_next_batch user[:followers] }.to raise_error(RuntimeError)

    expect(batches_processed).to eq(0)
    expect(actual_purged).to eq([])

    # Go again
    expect { purger.purge_next_batch user[:followers] }.to raise_error(Purge::DoneWithBatch)
    expect(batches_processed).to eq(1)
    first_batch_purged = expected_purged { _1 < batch_size }
    expect(actual_purged).to contain_exactly(*first_batch_purged)

    # Another error
    expect(criteria).to receive(:check_batch).and_raise(RuntimeError)

    expect { purger.purge_next_batch user[:followers] }.to raise_error(RuntimeError)
    expect(batches_processed).to eq(1)
    expect(actual_purged).to contain_exactly(*first_batch_purged)

    # Finally, finish
    2.times do
      expect { purger.purge_next_batch user[:followers] }.to raise_error(Purge::DoneWithBatch)
    end
    expect(batches_processed).to eq(3)
    expect(actual_purged).to contain_exactly(*expected_purged)
  end

  def batches_processed
    mock_redis.get("purge-#{user[:id]}-batches-processed").to_i
  end

  def expected_purged(&filter_block)
    user[:followers].values_at(*failing_follower_indices.filter(&(filter_block || :itself)))
  end

  def actual_purged
    mock_redis.smembers("purged-followers-#{user[:id]}").map { |u| JSON.parse(u) }
  end

end