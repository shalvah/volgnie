require 'sinatra'

set :views, settings.root + '/../views'

get '/' do
  # puts request.env['serverless.event']
  # puts request.env['serverless.context']
  html :index
end


def html(view)
  File.read(File.join(settings.views, "#{view.to_s}.html"))
end