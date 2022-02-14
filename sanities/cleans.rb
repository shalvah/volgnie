user = {
  "id" => "1",
  "following_count" => 138,
  "followers_count" => 7000,
  "username" => "Twitter",
}
purge_config = {
  "report_email" => "hello@shalvah.me",
  "level" => 2,
  "__simulate" => false,
  "trigger_time" => Time.now.-(60 * 60 * 3)
}
purged_followers = rand(0..5).times.map do
  {
    id: rand(100_000_000).to_s,
    username: ('A'..'z').to_a.shuffle.first(10).join,
  }
end

Services[:cache].lpush("purged-followers-#{user["id"]}", purged_followers.map(&:to_json)) if purged_followers.size > 0

puts "Purged followers: #{purged_followers.size}"

begin
  cleaner = Purge::Cleaner.build(user, purge_config)
  cleaner.clean

  pf = Services[:cache].lrange("purged-followers-#{user["id"]}", 0, -1)
  puts pf
  sleep 2
  raise StandardError.new("purged followers not deleted") if pf.size > 0
ensure
  Services[:cache].del("purged-followers-#{user["id"]}", 0, -1)
end

# Assertions (check manually)
# 1. Received "Purge complete" email from "purged@volgnie.com" at "hello@shalvah.me"
# 2. Email removed {purged_followers.size} followers
# 3. User should have 7000 - {purged_followers.size} followers
# 4. There should be a new CloudWatch metric