module PrismWeb
  class SharesController < ApplicationController
    skip_before_action :authenticate_prism!, only: [:show, :data]

    def show
      @share_token = ShareToken.find_by!(token: params[:token])

      unless @share_token.accessible?
        render json: { errors: ["Share token expired"] }, status: :gone
        return
      end

      case @share_token.resource_type
      when "SavedQuery"
        @resource = SavedQuery.find(@share_token.resource_id)
        render :show_saved_query
      when "Dashboard"
        @resource = Dashboard.find(@share_token.resource_id)
        render :show_dashboard
      else
        render json: { errors: ["Unknown resource type"] }, status: :bad_request
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: ["Resource not found"] }, status: :not_found
    end

    def data
      @share_token = ShareToken.find_by!(token: params[:token])

      unless @share_token.accessible?
        render json: { errors: ["Share token expired"] }, status: :gone
        return
      end

      case @share_token.resource_type
      when "SavedQuery"
        saved_query = SavedQuery.find(@share_token.resource_id)
        variables = params[:variables]&.permit! || {}

        result = query_engine.execute(
          saved_query.sql,
          variables: variables.to_h,
          connection_slug: saved_query.connection_slug
        )

        render json: {
          data: {
            rows: result.rows,
            columns: result.columns
          },
          meta: {
            row_count: result.row_count,
            duration_ms: result.duration_ms
          }
        }, status: :ok
      else
        render json: { errors: ["Unknown resource type"] }, status: :bad_request
      end
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: ["Resource not found"] }, status: :not_found
    end

    private

    def authenticate_prism!
      return if public_share_token?

      super
    end

    def public_share_token?
      ShareToken.find_by(token: params[:token]).present?
    end
  end
end