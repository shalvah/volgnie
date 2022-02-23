# frozen_string_literal: true

ENV["OTEL_TRACES_EXPORTER"] = "otlp"
if ENV["APP_ENV"] == "development"
  ENV["OTEL_LOG_LEVEL"] = "info"
  ENV["OTEL_BSP_SCHEDULE_DELAY"] = "0"
  ENV["OTEL_BSP_EXPORT_TIMEOUT"] = "0"
  ENV["OTEL_RUBY_BSP_START_THREAD_ON_BOOT"] = "false"
end
ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://api.honeycomb.io"
ENV["OTEL_EXPORTER_OTLP_HEADERS"] = "x-honeycomb-team=#{ENV.fetch("HONEYCOMB_API_KEY")},x-honeycomb-dataset=volgnie"
ENV["OTEL_TRACES_SAMPLER"] = "traceidratio"
ENV["OTEL_TRACES_SAMPLER_ARG"] = "1"
ENV["OTEL_RESOURCE_ATTRIBUTES"] = "SampleRate=1"

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

  otel_exporter = OpenTelemetry::Exporter::OTLP::Exporter.new
  OTelProcessor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(otel_exporter)
  c.add_span_processor(OTelProcessor)

  if ENV["APP_ENV"] != "test"
    c.use 'OpenTelemetry::Instrumentation::Sinatra'
    c.use 'OpenTelemetry::Instrumentation::RestClient'
    c.use 'OpenTelemetry::Instrumentation::Redis'
    c.use 'OpenTelemetry::Instrumentation::AwsSdk'
  end
end

def set_hb_req_id(context)
  return if ENV["APP_ENV"] == "test"

  Honeybadger.context({ aws_request_id: context.aws_request_id })

  current_span = OpenTelemetry::SDK.current_span
  current_span.set_attribute({
    "request_id" => context.aws_request_id,
    "user.id" => user_id
  })
end