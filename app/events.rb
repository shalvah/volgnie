# frozen_string_literal: true

require_relative '../lib/aws'

class Events
  EVENT_HANDLERS = {
    "purge_start" => "start_purge",
    "fetched_followers" => "purge_batch",
  }
  @@__dispatched = []

  class << self
    def purge_start(user, purge_config)
      payload = { user: user, purge_config: purge_config }
      dispatch("purge_start", payload)
    end

    def fetched_followers(followers, user, purge_config)
      payload = { followers: followers, user: user, purge_config: purge_config}
      dispatch("fetched_followers", payload)
    end

    def purge_finish(user, purge_config)
      payload = { user: user, purge_config: purge_config}
      dispatch("purge_finish", payload)
    end

    def dispatch(topic, payload)
      case ENV["APP_ENV"]
      when "development"
        # On local, run the function directly
        event = fake_sns_event(payload).to_json.to_json # Yep
        command = "sls invoke local -f #{EVENT_HANDLERS[topic]} -d #{event}"
        # Note: for some reason, `sls invoke``deletes the rack_adapter handler,
        # so, after this, you'll have to recreate it with `npm run offline:build``
        spawn(command, { [STDERR, STDOUT] => STDOUT })
      when "test"
        @@__dispatched << { event: topic, payload: payload }
      else
        client = Aws::SNS::Client.new
        client.publish({
          message: payload.to_json,
          topic_arn: topic_arn(topic)
        })
      end
    end
    private(:dispatch)

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

    def __dispatched
      @@__dispatched
    end

    def __clear_dispatched
      @@__dispatched = []
    end
  end
end