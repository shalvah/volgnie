# Flow

## Components
### Frontend
The entry point is the home page. It's a basic landing page, then the user clicks "Sign in with Twitter" to authorize the app. Eventually, they're brought back to the app, where they then configure their purge settings and click "Start".

This fires off an async event, `purge_start`, and immediately returns to another page, telling the user the purge has been started and they'll receive a report when it's done, along with an estimate of when (target time is < an hour).

### `purge_start`
When the `purge_start` event is fired, it is picked up by the `start_purge` Lambda. This function:
- fetches and stores the user's following
- fetches the user's followers in chunks of 1000 (to a limit of 5k), and dispatches the `new_batch`event for each chunk
- records the total number of batches dispatched

### `new_batch`
The `new_batch` event is handled by the `purge_batch` Lambda. For each follower in the batch, it runs the needed checks:
- checks if the user follows them (don't purge)
- checks if the user has interacted with them in recent times (don't purge)

If the user fails the criteria, they are purged (block/unblock) and recorded.

When the batch is done, the handler increments the total number of batches processed. If this is the final batch (`batches_processed == batches_dispatched`), the handler fires the `purge_finish` event.

### `purge_finish`
This event is handled by the `finish_purge` Lambda. It fetches the list of purged followers and:
- sends an email report
- records any final metrics
- clears any unneeded data (such as the user's followers)

## Failure handling
### What happens if a batch fails midway?
- This means the batch won't be recorded as processed, and the data will be lost.

#### Mitigation:
Wrap every batch in an error handler. If a failure happens, serialise the batch's state (total, amount processed, amount not processed) and report the error so it can be retried manually later. Even better: automatic retries—schedule the function to re-run later.

## What happens if a failure happens while dispatching batches?
- We'll store the last pagination token for the user's followers. If the token is available