# frozen_string_literal: true

require "prism/core/configuration"
require "prism/core/errors"
require "prism/core/credentials_loader"
require "prism/core/connection_manager"
require "prism/core/statement_validator"
require "prism/core/variable_interpolator"
require "prism/core/query_engine"
require "prism/core/schema_context_builder"

module Prism
  VERSION = "0.1.0"

  def self.configure(&block)
    Configuration.configure(&block)
  end
end