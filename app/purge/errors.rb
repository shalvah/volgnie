module Purge

  class ErrorDuringPurge < StandardError
  end

  class OutOfTime < ErrorDuringPurge
  end

  class SearchHandlerFailed < ErrorDuringPurge
  end
end