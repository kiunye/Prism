# frozen_string_literal: true

require "test_helper"

class PrismCoreTest < Minitest::Test
  def test_module_loads
    assert_equal "0.1.0", Prism::VERSION
  end
end