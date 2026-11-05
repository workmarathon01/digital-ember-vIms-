module Fcm
  # Google rejected the service-account assertion or the OAuth token request.
  class AuthenticationError < Error; end
end
