# frozen_string_literal: true

# Basic structs so we don't have to struggle with "is it hash[:key] or hash['key']?" all the time

# Example:
# {
#   "username": "theshalvah",
#   "name": "jukai (樹海)",
#   "id": "876342319217332225",
#   "public_metrics": {
#     "followers_count": 7354,
#     "following_count": 138,
#     "tweet_count": 43875,
#     "listed_count": 62
#   },
#   "profile_image_url": "https://pbs.twimg.com/profile_images/1348334243898945536/1r1J6_vE_normal.jpg",
#   "protected": false
# }
TwitterUser = Struct.new(
  :username, :name, :id, :public_metrics, :profile_image_url, :protected,
  keyword_init: true
) do
  def to_json(options = {})
    to_h.to_json # Seriously, Ruby?
  end
end

AppUser = Struct.new(
  :id, :following_count, :followers_count, :username,
  keyword_init: true
) do
  def to_json(options = {})
    to_h.to_json # Seriously, Ruby?
  end

  def self.from_twitter(user)
    new(
      id: user.id,
      following_count: user.public_metrics["following_count"],
      followers_count: user.public_metrics["followers_count"],
      username: user.username,
    )
  end

  # This is important because values may be passed as-is on local, or converted to JSON over the network
  def self.from(user)
    return user if user.is_a?(AppUser)
    return self.from_twitter(user) if user.is_a?(TwitterUser)

    new(**user)
  end
end

PurgeConfig = Struct.new(
  :level, :__simulate, :report_email, :trigger_time,
  keyword_init: true
) do
  def to_json(options = {})
    to_h.to_json # Seriously, Ruby?
  end

  # This is important because values may be passed as-is on local, or converted to JSON over the network
  def self.from(purge_config)
    return purge_config if purge_config.is_a?(PurgeConfig)

    if purge_config[:trigger_time].nil? && purge_config["trigger_time"].nil?
      purge_config[:trigger_time] = Time.now.to_i
    end
    new(**purge_config)
  end
end