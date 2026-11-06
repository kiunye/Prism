# frozen_string_literal: true

require "test_helper"

class PrismCoreTest < Minitest::Test
  def test_module_loads
    assert_equal "0.1.0", Prism::VERSION
  end
end
class PrismConfigTest < Minitest::Test
  def test_configure_stores_the_configuration_for_prism_config
    config = Prism.configure { query.max_rows = 5 }

    assert_same config, Prism.config
    assert_equal 5, Prism.config.query.max_rows
  end
end
