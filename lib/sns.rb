require_relative './aws'

client = Aws::SNS::Client.new(
  region: ENV.fetch("AWS_REGION"),
)