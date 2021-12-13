# frozen_string_literal: true

source "https://rubygems.org"

gem "sinatra", "~> 2.1"
gem "rack-protection", "~> 2.1"

gem "omniauth", "~> 2.0"
gem "omniauth-twitter", "~> 1.4"
gem "aws-sdk-cloudwatch", "~> 1.59"
gem "aws-sdk-lambda", "~> 1.76"
gem "aws-sdk-sns", "~> 1.48"
gem "honeybadger", "~> 4.9"

gem "rest-client", "~> 2.1"
gem "oauth", "~> 0.5.8"

gem "redis", "~> 4.5"
gem "mail", "~> 2.7"

group :test do
  gem "rspec", "~> 3.10"
  gem "webmock", "~> 3.14"
  gem "rack-test", "~> 1.1"
  gem "mock_redis", "~> 0.29.0"
  gem "factory_bot", "~> 6.2"
  gem "faker", "~> 2.19"
end

group :development do
  gem "ruby-ray"
end

# Adding these so serverless-rack + serverless-offline uses the local packed gems,
# not the global Ruby ones, which causes conflicts
gem "base64"
gem "date"
gem "erb"
gem "json"

