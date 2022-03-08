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
  "trigger_time" => Time.now.-(60 * 60 * 3).to_i
}
purged_followers = rand(0..5).times.map do
  {
    id: rand(100_000_000).to_s,
    username: ('A'..'z').to_a.shuffle.first(10).join,
  }
end

# Prep
Services[:cache].sadd("purged-followers-#{user["id"]}", purged_followers.map(&:to_json)) if purged_followers.size > 0
Services[:cache].del("clean-#{user["id"]}-report")
Services[:cache].del("clean-#{user["id"]}-record")

puts "Purged followers: #{purged_followers.size}"

begin
  cleaner = Purge::Cleaner.build(user, purge_config)
  cleaner.clean

  pf = Services[:cache].smembers("purged-followers-#{user["id"]}")
  puts pf
  sleep 2
  raise StandardError.new("purged followers not deleted") if pf.size > 0
ensure
  Services[:cache].del("purged-followers-#{user["id"]}")
end

puts <<TEXT

Seems good; verify assertions manually:

1. Received "Purge complete" email from "purged@volgnie.com" at "hello@shalvah.me"
2. Email removed #{pf.size} followers
3. User should have #{7000 - pf.size} followers
4. There should be a new CloudWatch metric
TEXT