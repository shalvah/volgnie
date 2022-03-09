# frozen_string_literal: true

ENV["OTEL_LOG_LEVEL"] = ENV["APP_ENV"] == "development" ? "debug" : "info"

instrumentation_enabled = ENV["APP_ENV"] != "test"

if instrumentation_enabled
  # We'll manually force send after each request
  ENV["OTEL_BSP_SCHEDULE_DELAY"] = "1000"

  # Configure the OTLP exporter
  ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://otlp.eu01.nr-data.net"
  ENV["OTEL_EXPORTER_OTLP_HEADERS"] = "api-key=#{ENV.fetch("NEW_RELIC_API_KEY")}"
  ENV["OTEL_EXPORTER_OTLP_TRACES_COMPRESSION"] = "none"

  ENV["OTEL_TRACES_EXPORTER"] = "none" # Override this later on for non-test env
  ENV["OTEL_TRACES_SAMPLER"] = "traceidratio"
  ENV["OTEL_TRACES_SAMPLER_ARG"] = "1"
  ENV["OTEL_RESOURCE_ATTRIBUTES"] = "SampleRate=1"
end

require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/sinatra'
require 'opentelemetry/instrumentation/restclient'
require 'opentelemetry/instrumentation/redis'
require 'opentelemetry/instrumentation/aws_sdk'

OpenTelemetry::SDK.configure do |c|
  c.resource = OpenTelemetry::SDK::Resources::Resource.create({
    OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'volgnie',
    OpenTelemetry::SemanticConventions::Resource::DEPLOYMENT_ENVIRONMENT => ENV["APP_ENV"],
  })

  if instrumentation_enabled
    otel_exporter = OpenTelemetry::Exporter::OTLP::Exporter.new
    processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(otel_exporter)
    c.add_span_processor(processor)
    OTelProcessor = processor

    c.use 'OpenTelemetry::Instrumentation::Sinatra'
    c.use 'OpenTelemetry::Instrumentation::RestClient'
    c.use 'OpenTelemetry::Instrumentation::Redis', { db_statement: :include }
    c.use 'OpenTelemetry::Instrumentation::AwsSdk'
  end
end

def set_context_data(context, user)
  return if ENV["APP_ENV"] == "test"

  Honeybadger.context({ aws_request_id: context.aws_request_id })

  current_span = OpenTelemetry::SDK.current_span
  current_span.set_attribute({
    "request_id" => context.aws_request_id,
    "user.id" => user["id"]
  })
end