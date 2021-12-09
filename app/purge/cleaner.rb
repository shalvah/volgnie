module Purge

  class Cleaner
    def self.build(user, purge_config)
      purged_users = Cache.lrange("purged-followers-#{user["id"]}", 0, -1).map { |v| JSON.parse(v) }

      new(user, purged_users, purge_config. Cache)
    end

    def initialize(user, purged_users, purge_config, cache)
      @user = user
      @purged_users = purged_users
      @purge_config = purge_config
      @cache = cache
    end

    def clean
      @cache.del("purged-followers-#{user["id"]}")
      clear_users_data(user)
    end

    def report
      send_email_report(@user, @purged_users, @purge_config)
    end

    def record
      report_metrics(@user, @purged_users, @purge_config)
    end
  end

end