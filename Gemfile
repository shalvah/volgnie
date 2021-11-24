# frozen_string_literal: true

source "https://rubygems.org"

group :test do
  gem "rspec", "~> 3.10"
end

gem "sinatra", "~> 2.1"

# Adding these so serverless-rack + serverless-offline uses the local packed gems,
# not the global Ruby ones, which causes conflicts
gem "json"
gem "base64"
