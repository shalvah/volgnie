# Flow

## Components
### Frontend
The entry point is the home page. It's a basic landing page, then the user clicks "Sign in with Twitter" to authorize the app. Eventually, they're brought back to the app, where they then configure their purge settings and click "Start".

This fires off an async event, `purge_start`, and immediately returns to another page, telling the user the purge has been started and they'll receive a report when it's done, along with an estimate of when (target time is < an hour).

### Event: `purge_start`
When the `purge_start` event is fired, it is picked up by the `start_purge` Lambda. This function:
- fetches and stores the user's following
- fetches the user's followers (to a limit of 1k), and dispatches the `purge_ready`event

### Event: `purge_ready`
The `purge_ready` event is handled by the `purge_followers` Lambda. It slices the follower list into batches and processes only the first. For each follower in the batch, it runs the needed checks, depending on the user's criteria (mutuals/interacted, etc). If the user fails the criteria, they are purged (block/unblock) and recorded. Then it sleeps until a set time (to avoid Twitter rate limits).

When next it is woken up, it processes the next batch. When there are no more batches to be processed, the handler fires the `purge_finish` event.

### Lambda: `push_next_batch`
Responsible for waking up `purge_followers`. Runs on an interval and dispatches any batches due to be processed.

### Event: `purge_finish`
This event is handled by the `finish_purge` Lambda. It fetches the list of purged followers and:
- sends an email report
- records any final metrics
- clears any unneeded data (such as the user's followers)

## Failure handling
All functions are designed to be idempotent, so they can be retried safely.
- On retry, `start_purge` will simply re-fetch the data again and fire the next event
- Each operation in `purge_finish` sets a cache key when it succeeds, so it won't run again if another op fails and entire fn is retried
- `purge_followers` fails to a Dead Letter Queue, preserving the payload. It also stores the number of batches processed. On retry, it skips past the batches processed and (re-)processes the next batch. Reprocessing a batch is cheap (only 10 users)