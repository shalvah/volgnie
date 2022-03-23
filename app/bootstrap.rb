require 'honeybadger'
Honeybadger.configure do |h|
  h.exceptions.ignore += ["Purge::DoneWithBatch"]
  h.env = ENV["APP_ENV"]
  h.breadcrumbs.enabled = true
  h.report_data = true
end

require_relative './config'
require_relative './models'
require_relative './helpers'
require_relative './lib/services'
require_relative './lib/cache'
require_relative './lib/twitter'
require_relative './events'
require_relative './lib/instrumentation'