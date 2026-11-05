ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Minitest 6 no longer ships `minitest/mock`, so keep a tiny, dependency-free
# stub helper for the few tests that need to replace a class method.
module MethodStubbing
  def with_stubbed_method(object, method_name, replacement)
    singleton = object.singleton_class
    original = object.method(method_name)
    singleton.send(:define_method, method_name) do |*args, **kwargs, &block|
      replacement.call(*args, **kwargs, &block)
    end
    yield
  ensure
    singleton&.send(:define_method, method_name, original) if original
  end
end

module ActiveSupport
  class TestCase
    include MethodStubbing

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
