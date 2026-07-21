# frozen_string_literal: true

require "test_helper"
require "prism/core/configuration"

class ConfigurationTest < Minitest::Test
  def test_minimal_valid_config
    config = Prism.configure do |c|
      c.owner_resolver = ->(r) { r.current_user }
      c.auth_guard = ->(r) { true }
      c.connection :primary do |conn|
        conn.reuse_host_pool = true
        conn.read_only_role = "prism_ro"
        conn.default = true
      end
    end

    assert config.owner_resolver
    assert config.auth_guard
    assert config.connections[:primary]
    assert_equal "primary", config.connections.default_slug
  end

  def test_missing_owner_resolver_raises
    error = assert_raises(Prism::ConfigurationError) do
      Prism.configure do |c|
        c.auth_guard = ->(r) { true }
        c.connection :primary do |conn|
          conn.reuse_host_pool = true
          conn.read_only_role = "prism_ro"
          conn.default = true
        end
      end.validate!
    end
    assert_match(/owner_resolver required/, error.message)
  end

  def test_missing_auth_guard_raises
    error = assert_raises(Prism::ConfigurationError) do
      Prism.configure do |c|
        c.owner_resolver = ->(r) { r.current_user }
        c.connection :primary do |conn|
          conn.reuse_host_pool = true
          conn.read_only_role = "prism_ro"
          conn.default = true
        end
      end.validate!
    end
    assert_match(/auth_guard required/, error.message)
  end

  def test_no_connections_raises
    error = assert_raises(Prism::ConfigurationError) do
      Prism.configure do |c|
        c.owner_resolver = ->(r) { r.current_user }
        c.auth_guard = ->(r) { true }
      end.validate!
    end
    assert_match(/no connections defined/, error.message)
  end

  def test_no_default_connection_raises
    error = assert_raises(Prism::ConfigurationError) do
      Prism.configure do |c|
        c.owner_resolver = ->(r) { r.current_user }
        c.auth_guard = ->(r) { true }
        c.connection :primary do |conn|
          conn.reuse_host_pool = true
          conn.read_only_role = "prism_ro"
          conn.default = false
        end
      end.validate!
    end
    assert_match(/no default connection/, error.message)
  end

  def test_multiple_connections
    config = Prism.configure do |c|
      c.owner_resolver = ->(r) { r.current_user }
      c.auth_guard = ->(r) { true }
      c.connection :primary do |conn|
        conn.reuse_host_pool = true
        conn.read_only_role = "prism_ro"
        conn.default = true
      end
      c.connection :analytics do |conn|
        conn.reuse_host_pool = false
        conn.credentials_file = "secrets/analytics.yml"
        conn.read_only_role = "prism_ro"
        conn.default = false
      end
    end

    assert_equal 2, config.connections.to_a.size
    assert config.connections[:primary]
    assert config.connections[:analytics]
  end

  def test_invalid_visibility_mode
    error = assert_raises(Prism::ConfigurationError) do
      Prism.configure do |c|
        c.owner_resolver = ->(r) { r.current_user }
        c.auth_guard = ->(r) { true }
        c.connection :primary do |conn|
          conn.reuse_host_pool = true
          conn.read_only_role = "prism_ro"
          conn.default = true
        end
        c.visibility.mode = :invalid
      end.validate!
    end
    assert_match(/invalid visibility mode/, error.message)
  end

  def test_dynamic_visibility_requires_resolver
    error = assert_raises(Prism::ConfigurationError) do
      Prism.configure do |c|
        c.owner_resolver = ->(r) { r.current_user }
        c.auth_guard = ->(r) { true }
        c.connection :primary do |conn|
          conn.reuse_host_pool = true
          conn.read_only_role = "prism_ro"
          conn.default = true
        end
        c.visibility.mode = :dynamic
      end.validate!
    end
    assert_match(/dynamic mode requires resolver/, error.message)
  end

  def test_middleware_stack
    config = Prism.configure do |c|
      c.owner_resolver = ->(r) { r.current_user }
      c.auth_guard = ->(r) { true }
      c.connection :primary do |conn|
        conn.reuse_host_pool = true
        conn.read_only_role = "prism_ro"
        conn.default = true
      end
      c.middleware.use(Class.new { def initialize(app); @app = app; end; def call(env, next_mw); @app.call(env); end })
    end

    assert_equal 1, config.middleware.instance_variable_get(:@stack).size
  end
end