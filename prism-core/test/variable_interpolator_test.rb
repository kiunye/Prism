# frozen_string_literal: true

require "test_helper"

class VariableInterpolatorTest < Minitest::Test
  def setup
    @interpolator = Prism::Core::VariableInterpolator.new
  end

  def test_replaces_placeholders_with_positional_parameters
    sql, params = @interpolator.interpolate(
      "SELECT * FROM users WHERE age > {{min_age}} AND name = {{name}}",
      [{ name: "min_age", type: :integer }, { name: "name", type: :string }],
      { "min_age" => "21", "name" => "Ada" }
    )

    assert_equal "SELECT * FROM users WHERE age > $1 AND name = $2", sql
    assert_equal [21, "Ada"], params.values
  end

  def test_never_interpolates_values_into_sql
    sql, params = @interpolator.interpolate(
      "SELECT * FROM users WHERE name = {{name}}",
      [{ name: "name", type: :string }],
      { "name" => "x'; DROP TABLE users; --" }
    )

    refute_includes sql, "DROP"
    assert_equal ["x'; DROP TABLE users; --"], params.values
  end

  def test_uses_default_when_value_not_provided
    _, params = @interpolator.interpolate(
      "SELECT {{n}}", [{ name: "n", type: :integer, default: 5 }], {}
    )

    assert_equal [5], params.values
  end

  def test_rejects_undefined_variable
    error = assert_raises(Prism::QueryError) do
      @interpolator.interpolate("SELECT {{nope}}", [], {})
    end

    assert_equal :variable_missing, error.code
  end

  def test_rejects_missing_required_value
    error = assert_raises(Prism::QueryError) do
      @interpolator.interpolate("SELECT {{n}}", [{ name: "n", type: :integer }], {})
    end

    assert_equal :variable_missing, error.code
  end

  def test_rejects_value_of_wrong_type
    error = assert_raises(Prism::QueryError) do
      @interpolator.interpolate("SELECT {{n}}", [{ name: "n", type: :integer }], { "n" => "abc" })
    end

    assert_equal :variable_type_error, error.code
  end

  def test_casts_boolean_and_dates_without_rails
    _, params = @interpolator.interpolate(
      "SELECT {{b}}, {{d}}",
      [{ name: "b", type: :boolean }, { name: "d", type: :date }],
      { "b" => "true", "d" => "2026-01-02" }
    )

    assert_equal [true, Date.new(2026, 1, 2)], params.values
  end
end
