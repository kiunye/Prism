# frozen_string_literal: true

module Prism
  class ConfigurationError < StandardError; end

  class QueryError < StandardError
    attr_reader :code, :sql_state

    CODES = {
      validation_failed:     "VALIDATION_FAILED",
      statement_rejected:    "STATEMENT_REJECTED",
      timeout:               "QUERY_TIMEOUT",
      row_limit:             "ROW_LIMIT_EXCEEDED",
      connection_failed:     "CONNECTION_FAILED",
      execution_failed:      "EXECUTION_FAILED",
      variable_missing:      "VARIABLE_MISSING",
      variable_type_error:   "VARIABLE_TYPE_ERROR",
      configuration_error:   "CONFIGURATION_ERROR",
    }.freeze

    def initialize(message, code: :execution_failed, sql_state: nil)
      super(message)
      @code = code
      @sql_state = sql_state
    end
  end
end