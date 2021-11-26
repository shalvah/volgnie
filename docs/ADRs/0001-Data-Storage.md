# Data Storage: Redis

The first consideration: what are we storing?
- Session information: This fits naturally with Redis.
- User credentials:
- User config
- Following
- Purged followers

We could model most of this as an SQL table, but there don't seem to be any major advantages over Redis:
- We aren't searching our data, so no need for indexes.
- All of our access can be easily modelled as key-value: `credentials-<user>`, `purged-followers-<user>`, etc.

In addition, all the data we're storing is short-term. We can set the data to automatically be cleared even if something happens.

If, in the future, we decide to expand functionality, we can write a script to migrate from Redis to a proper database.

## Reliability
Redis is transient by default, but we'll use a provider that offers persistence, such as ScaleGrid. However, none of this data is critical—most of the data can be fetched again.

## Capacity
The biggest values stored will probably be the *purged followers* and *user's following*.

### Followings:
Most people's followings are in the hundreds to low thousands. A few are probably in the tens of thousands. However, we have a hard cap of 5k on the followings we fetch (because of Twitter's API limits).

Also, we'll only be storing the usernames, as a list of strings. Twitter's username length is 15 ASCII characters max, leaving us at 150kB if a user is following 10k people.

The max list size in Redis is more than 4 bn elements, and each string can be up to 512 MB ([source](https://redis.io/topics/data-types)), so we won't hit Redis' limits for a single user. Additionally, even if we have 100 users following 150k people each being fetched concurrently, we should be fine.

### Purged followers
Same reasoning as for followings applies. We will only fetch the user's first 5k followers at first. They can run the purge again if they wish to remove more.

## Security considerations
Redis is designed for simplicity, not security. However, the only sensitive data we'll store are the user credentials and (to a lesser extent) session information, which will all be cleared after a short interval. In addition, the Redis instance will be secured and only accessible in the Lambda function's VPC (I think ScaleGrid provides this).