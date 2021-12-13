require_relative '../../lib/mailer'
require 'aws-sdk-cloudwatch'

module Purge

  class Cleaner
    def self.build(user, purge_config)
      cloudwatch_client = Aws::CloudWatch::Client.new

      new(user, purge_config, Cache, cloudwatch_client)
    end

    def initialize(user, purge_config, cache, cloudwatch_client)
      @user = user
      @purge_config = purge_config
      @cache = cache
      @cloudwatch_client = cloudwatch_client
      @purged_followers = cache.lrange("purged-followers-#{user["id"]}", 0, -1).map { |v| JSON.parse(v) }
    end

    def clean
      tasks = [Thread.new { report }, Thread.new { record }]
      tasks.map(&:join)
      @cache.del("purged-followers-#{@user["id"]}")
    end

    def report
      subject = @purge_config["__simulate"] ? "[SIMULATED] Twitter Purge Complete!" : "Twitter Purge Complete!"
      Mailer.new(@purge_config["report_email"], subject)
        .view(:report_mail, { purged_followers: @purged_followers, user: @user })
        .send!
    end

    def record
      return if @purge_config["__simulate"] || (ENV["CLOUDWATCH_METRICS"] === "off")

      payload = {
        metric_data: [
          {
            metric_name: "PurgesCount",
            unit: 'Count',
            value: 1
          },
          {
            metric_name: "PurgedFollowersCount",
            unit: 'Count',
            value: @purged_followers.size
          },
          {
            metric_name: "TotalFollowersCount",
            unit: 'Count',
            value: @user["followers_count"]
          },
        ],
        namespace: 'Volgnie'
      }
      @cloudwatch_client.put_metric_data(payload)
    end
  end

end