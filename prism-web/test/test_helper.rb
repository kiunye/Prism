ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)

  def setup
    @owner = { id: 1, type: "User" }
    Current[:owner] = @owner
  end

  def teardown
    Current.reset
  end
end