require 'erb'
require 'mail'

class Mailer
  def initialize(to_address, subject)
    @from = AppConfig[:mail][:from]
    @to = to_address
    @subject = subject
  end

  def view(name, locals)
    @view = name
    @locals = locals
    self
  end

  def send!
    mail = Mail.new do |m|
      m.from @from
      m.to @to
      m.subject @subject
      m.content_type 'text/html; charset=UTF-8'
      m.body ERB.new(load_template).result(binding)
    end

    mail.delivery_method(AppConfig[:mail][:delivery_method], **AppConfig[:mail][:settings])
    mail.deliver

    if mail.bounced? || mail.action == "failed"
      raise StandardError, "Mail sending failed"
    end

    mail
  end

  private
  def load_template
    File.read(File.expand_path("../views/#{@view.to_s}.erb", __dir__))
  end
end