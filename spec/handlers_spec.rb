require_relative '../handler'
require_relative '../app/purge/preparer'
require_relative '../app/purge/criteria'

RSpec.describe "handlers" do
  user = nil
  Purge::DEFAULT_FOLLOWER_LIMIT = 20 # Only check the first 20 followers

  before(:all) do
    # Set up a fake user and followers that we'll run our test on.
    # We'll also dispatch all events synchronously and mock the Twitter API
    # This user has 20 followers, 6 of which they are also following
    followers = 20.times.map { build(:user) }
    following = 4.times.map { build(:user) }
    user = build(:user, followers: followers, following: following)
    Mutuals = 6.times.map {
      index = Faker::Number.unique.within(range: 0...20).to_i
      user[:followers][index]
    }
    user[:following].concat(Mutuals).shuffle!
    Faker::Number.unique.clear
    RepliedTo = user[:followers].sample(Faker::Number.unique.within(range: 1...12).to_i).map { _1[:username] }
    BeenRepliedTo = user[:followers].sample(Faker::Number.unique.within(range: 1...12).to_i).map { _1[:username] }
    User = user

    class SynchronousDispatcher < LocalDispatcher
      def dispatch(topic, payload)
        event = fake_sns_event(payload)
        context = Class.new do
          define_method(:aws_request_id) { "123" }
          define_method(:function_name) { "123" }
        end.new
        send(EVENT_HANDLERS[topic], { event: event, context: context })
      end
    end

    class FakeTwitterApi < TwitterApi
      def get_following(id, options = {}, &block)
        User[:following]
      end

      def get_followers(id, options = {}, &block)
        catch(:stop_chunks) do
          User[:followers].each_slice(Purge::DEFAULT_FOLLOWER_LIMIT) { |s| block.call(s, {}) }
        end
      end

      def block(source_user_id, target_user_id) end

      def unblock(source_user_id, target_user_id) end
    end

    class FakeRelationshipChecker < ::Purge::RelationshipChecker
      def has_replied_to_follower_bulk(followers)
        followers.map { |f| RepliedTo.include?(f["username"]) }
      end

      def has_replied_or_been_replied_to_bulk(followers)
        followers.map { |f| RepliedTo.include?(f["username"]) || BeenRepliedTo.include?(f["username"]) }
      end
    end

    Services[:dispatcher] = SynchronousDispatcher.new
    Services[:twitter] = FakeTwitterApi.new
    Services[:relationship_checker] = FakeRelationshipChecker
  end

  before(:each) do
    Mail::TestMailer.deliveries.clear
    Services[:cache].set("keys-#{user[:id]}", { token: "sometoken", secret: "somesecret" }.to_json)
  end

  after(:each) do
    Services[:cache].flushall
  end

  after(:all) do
    Services.__clear_resolved
  end

  it "purges non-mutuals" do
    payload = purge_payload(user, Purge::Criteria::MUTUAL)

    purge(payload)

    mail = Mail::TestMailer.deliveries[0]
    expect(AppConfig[:mail][:from].end_with?("<#{mail.from[0]}>")).to be(true)
    expect(mail.to).to match([payload["purge_config"]["report_email"]])
    purged_count = user[:followers].size - Mutuals.size
    expect(mail.body.raw_source).to match("<b>#{purged_count}</b> of your followers matched that criteria and were removed.")
    expect(Services[:cache].smembers("purged-followers-#{user[:id]}")).to be_empty
  end

  it "purges non-replied-to but keeps mutuals" do
    payload = purge_payload(user, Purge::Criteria::MUST_HAVE_REPLIED_TO)

    purge(payload)

    mail = Mail::TestMailer.deliveries[0]
    expect(AppConfig[:mail][:from].end_with?("<#{mail.from[0]}>")).to be(true)
    expect(mail.to).to match([payload["purge_config"]["report_email"]])
    purged_count = user[:followers].size - (RepliedTo + Mutuals.map { _1[:username] }).uniq.size
    expect(mail.body.raw_source).to match("<b>#{purged_count}</b> of your followers matched that criteria and were removed.")
    expect(Services[:cache].smembers("purged-followers-#{user[:id]}")).to be_empty
  end

  it "purges non-interacted-with but keeps mutuals" do
    payload = purge_payload(user, Purge::Criteria::MUST_HAVE_INTERACTED)

    purge(payload)

    mail = Mail::TestMailer.deliveries[0]
    expect(AppConfig[:mail][:from].end_with?("<#{mail.from[0]}>")).to be(true)
    expect(mail.to).to match([payload["purge_config"]["report_email"]])
    purged_count = user[:followers].size - (BeenRepliedTo + RepliedTo + Mutuals.map { _1[:username] }).uniq.size
    expect(mail.body.raw_source).to match("<b>#{purged_count}</b> of your followers matched that criteria and were removed.")
    expect(Services[:cache].smembers("purged-followers-#{user[:id]}")).to be_empty
  end

  it "sends no_users_purged report if no users purged" do
    payload = purge_payload(user, Purge::Criteria::MUTUAL)
    old_following = User[:following]
    User[:following] = User[:followers] # Everybody is a mutual

    purge(payload)

    mail = Mail::TestMailer.deliveries[0]
    expect(AppConfig[:mail][:from].end_with?("<#{mail.from[0]}>")).to be(true)
    expect(mail.to).to match([payload["purge_config"]["report_email"]])
    expect(mail.body.raw_source).to match("None of your followers matched that criteria")
    expect(Services[:cache].smembers("purged-followers-#{user[:id]}")).to be_empty
    User[:following] = old_following
  end

  it "will only fetch followers up to the limit" do
    extra_followers = 5.times.map { build(:user) }
    user[:followers].concat(extra_followers)

    payload = purge_payload(user, Purge::Criteria::MUTUAL)
    purge(payload)

    mail = Mail::TestMailer.deliveries[0]
    expect(AppConfig[:mail][:from].end_with?("<#{mail.from[0]}>")).to be(true)
    expect(mail.to).to match([payload["purge_config"]["report_email"]])
    purged_count = user[:followers].size - Mutuals.size - extra_followers.size
    expect(mail.body.raw_source).to match("<b>#{purged_count}</b> of your followers matched that criteria and were removed.")
    expect(Services[:cache].smembers("purged-followers-#{user[:id]}")).to be_empty

    user[:followers] = user[:followers][0..19]
  end
end

def event(name, payload)
  {
    event: name,
    payload: payload
  }
end

def purge(payload)
  Events.purge_start(payload["user"], payload["purge_config"])
rescue Purge::DoneWithBatch
  retry
end