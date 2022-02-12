# frozen_string_literal: true

require_relative './aws'

# Dispatches to AWS SNS
class SnsDispatcher
  def dispatch(topic, payload)
    client = Aws::SNS::Client.new
    client.publish({
      message: payload.to_json,
      topic_arn: topic_arn(topic)
    })
  end

  def topic_arn(topic)
    ["arn:aws:sns", ENV.fetch("AWS_REGION"), ENV.fetch("AWS_ACCOUNT_ID"), topic].join(":")
  end
end

# Doesn't dispatch any events; just records them. Good for unit tests.
class FakeDispatcher
  attr_reader :dispatched

  def initialize
    @dispatched = []
  end

  def dispatch(topic, payload)
    @dispatched << { event: topic, payload: payload }
  end

  def clear
    @dispatched = []
  end
end

# Invokes the respective function in a separate process. Useful for dev.
class LocalDispatcher
  EVENT_HANDLERS = {
    purge_start: "start_purge",
    fetched_followers: "purge_followers",
    purge_finish: "finish_purge",
  }

  def dispatch(topic, payload)
    # On local, run the function in a separate process
    event = fake_sns_event(payload).to_json.to_json # Yep
    command = "sls invoke local -f #{EVENT_HANDLERS[topic]} -d #{event}"
    # Note: for some reason, `sls invoke``deletes the rack_adapter handler,
    # so, after this, you'll have to recreate it with `npm run offline:build``
    spawn(command, { [STDERR, STDOUT] => STDOUT })
  end

  def fake_sns_event(payload)
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
end