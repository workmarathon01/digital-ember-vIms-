module Fcm
  # A temporary network/provider problem. Jobs may retry these.
  class TransientError < Error; end
end
