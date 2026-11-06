module PrismWeb
  class ApplicationController < ::ActionController::Base
    include Current

    before_action :authenticate_prism!

    private

    def authenticate_prism!
      return if skip_authentication?

      if Prism.config.auth_guard.present? && !Prism.config.auth_guard.call(request)
        render json: { errors: ["Authentication required"] }, status: :unauthorized
        return
      end

      set_current_owner
    end

    def skip_authentication?
      return true if public_share_token?

      false
    end

    def set_current_owner
      return if Current.owner.present?

      if Prism.config.owner_resolver.present?
        Current.owner = Prism.config.owner_resolver.call(request)
      end
    end

    def public_share_token?
      token = request.path.match(%r{/share/([^/]+)})
      return false unless token

      ShareToken.find_by(token: token[1]) && 
        !token[1].match?(/data/)
    end

    def connection_manager
      @connection_manager ||= Prism::Core::ConnectionManager.new(Prism.config)
    end

    def query_engine
      @query_engine ||= Prism::Core::QueryEngine.new(
        connection_manager: connection_manager,
        timeout: Prism.config.query.timeout,
        max_rows: Prism.config.query.max_rows
      )
    end

    def schema_inspector
      @schema_inspector ||= Prism::Core::SchemaInspector.new(
        connection_manager,
        Prism.config.visibility
      )
    end

    def schema_context_builder
      @schema_context_builder ||= Prism::Core::SchemaContextBuilder.new(
        connection_manager,
        Prism.config.visibility
      )
    end
  end
end