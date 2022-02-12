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
)

AppUser = Struct.new(
  :id, :following_count, :followers_count, :username,
  keyword_init: true
) do
  def self.from_twitter_user(user)
    new(
      id: user.dig(:id),
      following_count: user.dig(:public_metrics, :following_count),
      followers_count: user.dig(:public_metrics, :followers_count),
      username: user.dig(:username),
    )
  end

  def self.from(user)
    return user if user.is_a?(AppUser)

    AppUser.new(**user)
  end
end