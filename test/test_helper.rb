require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# stub_method replaces Object#stub removed in minitest 6.x.
# Usage: stub_method(SomeClass, :method_name, value_or_callable) { ... }
def stub_method(obj, method_name, value_or_callable)
  original = obj.method(method_name)
  if value_or_callable.respond_to?(:call)
    obj.define_singleton_method(method_name) { |*args, **kwargs| value_or_callable.call(*args, **kwargs) }
  else
    obj.define_singleton_method(method_name) { |*args, **kwargs| value_or_callable }
  end
  yield
ensure
  obj.define_singleton_method(method_name, original)
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    include Warden::Test::Helpers

    setup { Warden.test_mode! }
    teardown { Warden.test_reset! }

    # Bypass Devise::Mapping.find_scope! which fails in parallel worker processes
    # when Devise.mappings may not be fully initialized. We know the scope is :user.
    def sign_in(user)
      login_as(user, scope: :user)
    end
  end
end
