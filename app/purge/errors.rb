module Purge

  class ErrorDuringPurge < StandardError
    attr_accessor :last_processed
    attr_accessor :processing
  end

  class OutOfTime < ErrorDuringPurge
  end

  class CouldntVerifyRelationship < ErrorDuringPurge
  end
end