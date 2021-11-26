# frozen_string_literal: true

source "https://rubygems.org"

group :test do
  gem "rspec", "~> 3.10"
  gem "rack-test", "~> 1.1"
end

group :development do
  gem "ruby-ray"
end

gem "sinatra", "~> 2.1"
gem "rack-protection", "~> 2.1"

gem "omniauth", "~> 2.0"
gem "omniauth-twitter", "~> 1.4"

gem "rest-client", "~> 2.1"
gem "oauth", "~> 0.5.8"

# Adding these so serverless-rack + serverless-offline uses the local packed gems,
# not the global Ruby ones, which causes conflicts
gem "json"
gem "base64"

