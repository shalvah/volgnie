require_relative '../lib/mailer'
require 'aws-sdk-cloudwatch'

module Purge

  # Cleans up after a purge
  # Sends an email report to the user, and records CloudWatch metrics
  class Cleaner
    def self.build(user, purge_config)
      cloudwatch_client = Aws::CloudWatch::Client.new
      new(user, purge_config, Services[:cache], cloudwatch_client)
    end

    def initialize(user, purge_config, cache, cloudwatch_client)
      @user = AppUser.from(user)
      @purge_config = PurgeConfig.from(purge_config)
      @cache = cache
      @cloudwatch_client = cloudwatch_client
      @purged_followers = cache.smembers("purged-followers-#{user["id"]}").map { |v| JSON.parse(v) }
    end

    def clean
      tasks = [Thread.new { report }, Thread.new { record }]
      tasks.map(&:join)
      @cache.del("purged-followers-#{@user.id}")
    end

    def report
      return if @cache.get("clean-#{@user.id}-report")

      subject = @purge_config.__simulate ? "[SIMULATED] Twitter Purge Complete" : "Twitter Purge Complete"
      Mailer.new(@purge_config.report_email, subject)
        .view(@purged_followers.empty? ? :report_empty_mail : :report_mail, {
          purged_followers: @purged_followers,
          user: @user,
          level: @purge_config.level,
          purge_trigger_time: Time.new(@purge_config.trigger_time).strftime("%B %-d, %Y at %H:%M:%S UTC%z")
        })
        .send!
      @cache.set("clean-#{@user.id}-report", 1, ex: 24 * 60 * 60)
    end

    def record
      return if @purge_config.__simulate || (ENV["CLOUDWATCH_METRICS"] == "off")
      return if @cache.get("clean-#{@user.id}-record")

      # todo track config
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
            value: @user.followers_count
          },
        ],
        namespace: 'Volgnie'
      }
      @cloudwatch_client.put_metric_data(payload)
      @cache.set("clean-#{@user.id}-record", 1, ex: 24 * 60 * 60)
    end
  end

end