# frozen_string_literal: true

require_relative '../lib/aws'

class Events
  EVENT_HANDLERS = {
    "purge_start" => "start_purge",
  }

  class << self
    def purge_start(user, purge_config)
      payload = { user: user, purge_config: purge_config }
      dispatch(payload, "purge_start")
    end

    def dispatch(payload, topic)
      case ENV["APP_ENV"]
      when "local", "test", "development"
        # On local, run the function directly
        event = fake_sns_event(payload).to_json.to_json # Yep
        command = "sls invoke local -f #{EVENT_HANDLERS[topic]} -d #{event}"
        # Note: for some reason, `sls invoke``deletes the rack_adapter handler,
        # so, after this, you'll have to recreate it with `npm run offline:build``
        spawn(command, {[STDERR, STDOUT] => STDOUT})
      else
        client = Aws::SNS::Client.new(
          region: region_name,
        )
        client.publish({
          message: payload.to_json,
          topic_arn: topic_arn(topic)
        })
      end
    end

    def topic_arn(topic)
      ["arn:aws:sns", ENV.fetch("AWS_REGION"), ENV.fetch("AWS_ACCOUNT_ID"), topic].join(":")
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
end