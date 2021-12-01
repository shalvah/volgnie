# frozen_string_literal: true

def default_if_empty(value, default)
  return default if really_empty?(value)
  value
end

def really_empty?(value)
  return true if value.nil?
  return true if value.respond_to?(:empty?) && value.empty?
  false
end

def get_sns_payload(event)
  JSON.parse(event["Records"][0]["Sns"]["Message"])
end

def get_user_creds(user_id)
  JSON.parse Cache.get("keys-#{user_id}")
end