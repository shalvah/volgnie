## Quota Considerations (aka, Avoiding Being Flagged by Twitter)

### Data
In my local tests:
- A call to Zearch for a batch of 10 users takes around 15s.
- Calls to the Twitter API (block/unblock) take around 800ms each.

### Limits
- block: 50 req/15 min
- unblock: 50 req/15 min

### Calculations
10 followers per batch = a maximum of (1.8s * 10) + 16s = 34s

Since the rate limit is 50 req/15 min, we could theoretically do 5 batches, then sleep for 15 minutes before doing another 5.
It would take (34s * 5) ~= 170 ~= 3 minutes to purge 5 batches, so we could purge 1k followers (100 batches) in 19(3 + 15) + 3min = 5h 45 minutes.

However, to prevent being flagged as spam for "abusing" block/unblock, we'll increase the interval to 20min and spread it between batches. Increasing the interval changes the time for 1k to ~440 mins (7h20m).

Next, spreading. We can do a batch, sleep for x minutes, then do another. This gives (n - 1)(34sec + x) + 34sec time to purge n batches. For 100 batches, this is 133sec + 99x = 440min, giving x ~= 4.4 minutes.

## Summary
Given time for one batch, t, and cooldown time as 20 mins (1200 sec)
- Time for n batches, t_n = (n/5 - 1)(5t + 1200) + 5t
- Time for 1k followers = 19(5t + 1200) + 5t
- Interval between n batches, i, is gotten from (n - 1)(t + i) + t = t_n = (n/5 - 1)(5t + 1200) + 5t
- i = ((n/5 - 1)(5t + 1200) + 5t) - nt)/(n - 1)
- Total time taken = (n - 1)(t + i) + t

## Results
We'll purge each batch (10 followers) then wait 4.2 minutes (250s). Purging will take 99(34 + 250) + 34 ~= 470min (nearly 8 hours)