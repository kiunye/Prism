# frozen_string_literal: true

require "test_helper"

class StatementValidatorTest < Minitest::Test
  def setup
    @validator = Prism::Core::StatementValidator.new
  end

  def test_accepts_plain_select
    assert @validator.validate("SELECT id, name FROM users LIMIT 10").valid
  end

  def test_accepts_select_with_read_only_cte
    assert @validator.validate("WITH t AS (SELECT 1 AS n) SELECT n FROM t").valid
  end

  %w[
    INSERT\ INTO\ users(name)\ VALUES('x')
    UPDATE\ users\ SET\ name='x'
    DELETE\ FROM\ users
    DROP\ TABLE\ users
    TRUNCATE\ users
    CREATE\ TABLE\ t(id\ int)
    ALTER\ TABLE\ users\ ADD\ COLUMN\ x\ int
    GRANT\ ALL\ ON\ users\ TO\ public
  ].each_with_index do |sql, i|
    define_method("test_rejects_write_statement_#{i}") do
      refute @validator.validate(sql).valid, "expected #{sql} to be rejected"
    end
  end

  def test_rejects_multi_statement_input_via_parser
    result = @validator.validate("SELECT 1; DROP TABLE users")

    refute result.valid
    assert_match(/multi-statement/i, result.errors.first)
  end

  def test_rejects_multi_statement_without_forbidden_keywords_in_first_statement
    refute @validator.validate("SELECT 1; SELECT 2").valid
  end

  def test_rejects_data_modifying_cte
    sql = "WITH d AS (DELETE FROM users RETURNING id) SELECT id FROM d"

    refute @validator.validate(sql).valid
  end

  def test_rejects_unparseable_sql
    result = @validator.validate("SELEC nonsense FROM")

    refute result.valid
    assert_match(/parse error/i, result.errors.first)
  end

  def test_rejects_select_into
    refute @validator.validate("SELECT * INTO new_table FROM users").valid
  end

  def test_rejects_locking_select
    refute @validator.validate("SELECT * FROM users FOR UPDATE").valid
  end

  def test_keyword_check_gives_readable_rejection_but_is_not_the_boundary
    assert_equal false, @validator.check_keywords("DELETE FROM users").valid
    # A column named "updated_at" must not trip the keyword UX check.
    assert @validator.check_keywords("SELECT updated_at FROM users").valid
  end
end
