module Purge

  class ErrorDuringPurge < StandardError
  end

  # Used to signal that we're done with this batch of followers
  # Will retry after a while
  class DoneWithBatch < ErrorDuringPurge
  end

  class SearchHandlerFailed < ErrorDuringPurge
  end
end