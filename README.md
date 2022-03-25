# Volgnie

If, like me, you *don't* like having too many Twitter followers, you've come to the right place. Volgnie helps you easily purge your Twitter followers. Pick from one of the available criteria, and any followers that don't meet it will be removed (by blocking/unblocking them). 

To use, go to [volgnie.com](https://volgnie.com), or read on for technical details.

## Technical details
## Tooling
- Ruby 2.7 and Node.js 14+
- [Serverless framework](http://serverless.com)
- serverless-offline plugin so we can test locally
- serverless-rack plugin so we can run a Sinatra web app in a Lambda function
- OpenTelemetry for tracing
- Redis for storage

## Components
### Lambda functions
> Tip: Take a look at the serverless.yml file. It's a concise description of the stack.

There are five key Lambda functions:
1. `web`: Handles volgnie.com and the whole web UI. Runs a Sinatra app via serverless-rack. Code is in `app/web.rb`.
2. `start_purge`: When you trigger a purge from the web app, an event (`purge_start`) is fired, which triggers this function. The `start_purge` function fetches the user's followers and following and fires the `purge_ready` event, which kicks off the purge by triggering the next function...
3. `purge_followers`: This takes a batch of followers, check if they match the user's criteria and purges the ones that fail. Then it sleeps. It does this batch-sleep thing to avoid hitting Twitter's rate limits.
4. `push_next_batch`: This runs at intervals and checks if enough time has passed for us to try the next batch. If so, it fires the `purge_ready` event again, so `purge_followers` can process the next batch before sleeping again.
5. `finish_purge`: When there are no more batches, the `purge_finish` event is fired, which triggers this function. The function sends a report of the purge to the user's email, records metrics and cleans up any unnecessary data. 

For more details, see the `docs/` folder.

### Search
The Twitter API's search only returns results from a few days, so I had to build a custom search implementation (a better version of what's currently on [oldtweets.today](http://oldtweets.today)), called Zearch. Unfortunately, it's not yet open source.

### External Services
- Honeybadger for error reporting, New Relic for OpenTelemetry traces (both optional)
- SendGrid (production) and Mailtrap (development) for emails
- AWS SNS (production) for events; in development, events are fired via spawning processes

## Setup
- Install dependencies:
  ```bash
  npm ci --production=false
  bundle install
  ```
- Copy `.env.example` to `.env` and set the needed environment variables
- Start Redis (easy way with Docker: `docker run --name redis --rm -p 6379:6379 redis`)
- Run the app locally:
  ```bash
  npm run offline
  ```

## Testing
Tests are written with RSpec. To run tests: `bundle exec rspec`
