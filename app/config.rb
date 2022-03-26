# frozen_string_literal: true

class AppConfig
  MailDrivers = {
    "test" => lambda { {
      delivery_method: :test,
      settings: {}
    } },
    "mailtrap" => lambda { {
      delivery_method: :smtp,
      settings: {
        address: ENV.fetch("MAILTRAP_HOST"),
        port: ENV.fetch("MAILTRAP_PORT").to_i,
        user_name: ENV.fetch("MAILTRAP_USERNAME"),
        password: ENV.fetch("MAILTRAP_PASSWORD"),
      }
    } },
    "sendgrid" => lambda { {
      delivery_method: :smtp,
      settings: {
        address: ENV.fetch("SENDGRID_HOST"),
        port: ENV.fetch("SENDGRID_PORT").to_i,
        user_name: ENV.fetch("SENDGRID_USERNAME"),
        password: ENV.fetch("SENDGRID_PASSWORD"),
      }
    } }
  }

  Configs = {
    default_follower_limit: 1000,
    resume_batch_in_seconds: 300,
    admins: [
      "theshalvah"
    ],
    mail: MailDrivers[ENV.fetch("MAIL_DRIVER")].call.merge({
      from: "Volgnie <purged@volgnie.com>"
    }),
  }

  class << self
    def get(key)
      raise StandardError.new("Unknown config key #{key}") unless Configs.has_key?(key)
      Configs[key]
    end

    def set(key, value)
      raise StandardError.new("Unknown config key #{key}") unless Configs.has_key?(key)
      Configs[key] = value
    end

    alias_method :[], :get
    alias_method :[]=, :set
  end
end