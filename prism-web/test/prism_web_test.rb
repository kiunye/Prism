# frozen_string_literal: true

require "test_helper"

class PrismWebTest < Minitest::Test
  def test_engine_loads
    assert PrismWeb::Engine < Rails::Engine
  end
end