require 'aws-sdk-sns'
require 'aws-sdk-lambda'

Aws.config.update({
  region: ENV.fetch("AWS_REGION"),
})

unless ENV["IS_OFFLINE"]
  Aws.config.update({
    credentials: Aws::Credentials.new(
      ENV.fetch("AWS_ACCESS_KEY_ID"),
      ENV.fetch("AWS_SECRET_ACCESS_KEY"),
    ),
  })
end