require_relative '../../app/purge/criteria'

RSpec.describe "Purge::Criteria" do
  let(:user) { build(:user) }
  let(:rc) { double(Purge::Criteria) }
  let(:purge_config) {
    PurgeConfig.from({
      "report_email" => "purge_here@volgnie.com",
      "level" => Purge::Criteria::MUST_HAVE_REPLIED_TO,
      "__simulate" => true,
    })
  }

  before(:each) do
    user[:following] = 5.times.map { build(:user) }.map { |f| stringify_keys(f) }
    expect(rc).to receive(:is_following).at_most(10).times do |f|
      user[:following].include?(f)
    end
  end

  it "check_batch passes if all are mutuals" do
    criteria = Purge::Criteria.new(purge_config, rc)
    followers = 5.times.map { user[:following].sample }
    expect(criteria.check_batch(followers)).to eq([true] * 5)
  end

  it "check_batch checks if non-mutuals" do
    expect(rc).to receive(:has_replied_to_follower_bulk).once do |batch|
      [false] * batch.size
    end

    criteria = Purge::Criteria.new(purge_config, rc)
    followers = 5.times.map { build(:user) }
    expect(criteria.check_batch(followers)).to eq([false] * 5)
  end

  it "check_batch correctly merges results of mutuals and non-mutuals" do
    expect(rc).to receive(:has_replied_to_follower_bulk).once do |batch|
      [false, false, true]
    end

    criteria = Purge::Criteria.new(purge_config, rc)
    followers = [user[:following].sample, build(:user), build(:user), user[:following].sample, build(:user)]
    expect(criteria.check_batch(followers)).to eq([true, false, false, true, true])
  end
end