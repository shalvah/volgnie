# frozen_string_literal: true

class Events
  class << self
    def purge_start(user, purge_config)
      payload = { user: user, purge_config: purge_config }
      dispatch(:purge_start, payload)
    end

    def ready_to_purge(followers, user, purge_config)
      payload = { followers: followers, user: user, purge_config: purge_config}
      dispatch(:ready_to_purge, payload)
    end

    def purge_finish(user, purge_config)
      payload = { user: user, purge_config: purge_config}
      dispatch(:purge_finish, payload)
    end

    private
    def dispatch(topic, payload)
      Services[:dispatcher].dispatch(topic, payload)
    end
  end
end