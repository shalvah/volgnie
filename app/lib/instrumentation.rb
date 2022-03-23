# frozen_string_literal: true

ENV["OTEL_LOG_LEVEL"] = case ENV["APP_ENV"]
  when "development";
    "debug"
  when "test";
    "fatal"
  else
    "info"
end

instrumentation_enabled = env_is_not?("test")
in_web_context = defined?(Sinatra)

if instrumentation_enabled
  # We'll manually force send after each request
  ENV["OTEL_BSP_SCHEDULE_DELAY"] = "1000"

  # Configure the OTLP exporter
  ENV["OTEL_EXPORTER_OTLP_ENDPOINT"] = "https://otlp.eu01.nr-data.net"
  ENV["OTEL_EXPORTER_OTLP_HEADERS"] = "api-key=#{ENV.fetch("NEW_RELIC_API_KEY")}"
  ENV["OTEL_EXPORTER_OTLP_TRACES_COMPRESSION"] = "none"

  ENV["OTEL_TRACES_EXPORTER"] = "none" # We override this later in this file for non-test env
  # COnfigure the TraceIdRatioBased with a prob of 1
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

    c.use('OpenTelemetry::Instrumentation::Sinatra') if in_web_context
    c.use 'OpenTelemetry::Instrumentation::RestClient'
    # c.use 'OpenTelemetry::Instrumentation::Redis', { db_statement: :include }
    # c.use 'OpenTelemetry::Instrumentation::AwsSdk'
  end
end

def flush_traces
  defined?(OTelProcessor) && OTelProcessor.shutdown(timeout: 10)
end

def lambda_transaction(context, payload = nil)
  Honeybadger.context({ aws_request_id: context.aws_request_id })

  tracer = OpenTelemetry.tracer_provider.tracer('custom')
  root_span = tracer.start_root_span(
    context.function_name,
    attributes: {
      'request.id' => context.aws_request_id,
    },
    kind: :server
  )
  OpenTelemetry::Trace.with_span(root_span) do |span, span_context|
    span.set_attribute('user.id', payload["user"]["id"]) if payload

    yield span, span_context
  end
rescue StandardError => e
  Honeybadger.notify(e)
  raise
ensure
  root_span&.finish
end