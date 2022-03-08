def assert(a, b)
  fail "Expected #{b}, got #{a}" if a != b
end

user = {
  "id" => "1",
  "following_count" => 138,
  "followers_count" => 7000,
  "username" => "Twitter",
}
purge_config = {
  "report_email" => "hello@shalvah.me",
  "level" => 2,
  "__simulate" => true,
  "trigger_time" => Time.now.-(60 * 60 * 3).to_i
}
followers = rand(13..15).times.map do
  {
    "id" => rand(100_000_000).to_s,
    "username" => ('A'..'z').to_a.shuffle.first(10).join,
  }
end
following = rand(0..3).times.map do
  {
    "id" => rand(100_000_000).to_s,
    "username" => ('A'..'z').to_a.shuffle.first(10).join,
  }
end
# Following only two of his followers
following.push(followers[7], followers[12])

# Prep
Services[:cache].set("following-#{user["id"]}", following.to_json, ex: 30 * 60)
Services[:cache].set("keys-#{user["id"]}", { token: "tokennn", secret: "secrettt" }.to_json, ex: 30 * 60)

purger = Purge::Purger.build(user, purge_config)

begin
  puts "Purging first batch"
  purger.purge_next_batch(followers)
rescue Purge::DoneWithBatch
  puts "Caught DoneWithBatch error as expected"
  pf = Services[:cache].smembers("purged-followers-#{user["id"]}")
  puts "Purged followers: #{pf.size}"
  assert(Services[:cache].get("purge-#{user["id"]}-batches-processed").to_i, 1)
  assert(pf.size, 9)

  begin
    puts "\nPurging second batch"
    purger.purge_next_batch(followers)
  rescue Purge::DoneWithBatch
    puts "Caught DoneWithBatch error as expected"
    pf = Services[:cache].smembers("purged-followers-#{user["id"]}")
    puts "Purged followers: #{pf.size}"
    assert(Services[:cache].get("purge-#{user["id"]}-batches-processed").to_i, 2)
    assert(pf.size, followers.size - 10 - 1 + 9)

    puts "\nPurging final try"
    purger.purge_next_batch(followers)
    puts "Finished safely, as expected"
    assert(Services[:cache].get("purge-#{user["id"]}-batches-processed").to_i, 2)
    return
  end
ensure
  Services[:cache].del("purged-followers-#{user["id"]}")
  Services[:cache].del("purge-#{user["id"]}-batches-processed")
end

fail "DoneWithBatch not raised"