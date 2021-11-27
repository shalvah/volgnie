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