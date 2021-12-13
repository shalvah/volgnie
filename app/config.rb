class Config
  PurgeLockDuration = 2 * 24 * 60 * 60

  Admins = [
    "theshalvah"
  ]

  class << self
    def mail
      case ENV.fetch("APP_ENV")
      when "development"
        delivery_method, settings = [:smtp,
          {
            address: ENV.fetch("MAILTRAP_HOST"),
            port: ENV.fetch("MAILTRAP_PORT").to_i,
            user_name: ENV.fetch("MAILTRAP_USERNAME"),
            password: ENV.fetch("MAILTRAP_PASSWORD"),
          }
        ]
      when "test"
        delivery_method, settings = [:test, {}]
      when "production"
        delivery_method, settings = [:smtp, {}]
      end

      {
        from: "purgereport@volgnie.app",
        delivery_method: delivery_method,
        settings: settings
      }
    end
  end
end