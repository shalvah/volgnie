=begin
require_relative '../app/web'
require 'rspec'

RSpec.describe "start_purge" do
  it "dispatches purge event" do
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
      }
    }
    start_purge(make_sns_event(payload), {})
    expect(Events.dispatched).to contain({ event: "fetched_followers", payload: payload })
  end
end

RSpec.describe "purge_batch" do
  it "dispatches purge event" do
  end
end

RSpec.describe "finish_purge" do
  it "dispatches purge event" do
  end
end

def make_sns_event(payload)
  # Abridged for simplicity; Full thing is at https://docs.aws.amazon.com/lambda/latest/dg/with-sns.html
  {
    "Records" => [
      {
        "Sns" => {
          "Timestamp" => "2019-01-02T12:45:07.000Z",
          "MessageId" => "95df01b4-ee98-5cb9-9903-4c221d41eb5e",
          "Message" => payload.to_json,
        }
      }
    ]
  }
end
=end
