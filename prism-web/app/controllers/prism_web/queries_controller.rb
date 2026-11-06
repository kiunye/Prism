module PrismWeb
  class QueriesController < ApplicationController
    def new
      render :new
    end

    def validate
      sql = params[:query]
      variables = params[:variables]&.to_unsafe_h || {}

      result = query_engine.validate(sql)
      render json: {
        data: {
          valid: result.valid,
          errors: result.errors || [],
          warnings: result.warnings || []
        },
        meta: { valid: result.valid }
      }, status: :ok
    rescue Prism::QueryError => e
      render json: { errors: [e.message] }, status: :bad_request
    end

    def execute
      sql = params[:query]
      variables = params[:variables]&.to_unsafe_h || {}
      connection_slug = params[:connection_slug].presence

      result = query_engine.execute(
        sql,
        variables: variables,
        connection_slug: connection_slug
      )

      respond_to do |format|
        format.json do
          render json: {
            data: {
              rows: result.rows,
              columns: result.columns
            },
            meta: {
              row_count: result.row_count,
              duration_ms: result.duration_ms,
              query_id: result.query_id,
              connection_slug: result.connection_slug,
              truncated: result.truncated
            }
          }, status: :ok
        end

        format.csv do
          response.headers["Content-Type"] = "text/csv"
          response.headers["Content-Disposition"] =
            "attachment; filename=\"query_#{result.query_id}.csv\""
          csv_body = result.to_csv.dup
          csv_body.rewind
          self.response_body = csv_body.read
        end
      end
    rescue Prism::QueryError => e
      render json: { errors: [e.message] }, status: :bad_request
    end

    def explain
      sql = params[:query]
      variables = params[:variables]&.to_unsafe_h || {}
      connection_slug = params[:connection_slug].presence

      result = query_engine.explain(
        sql,
        variables: variables,
        connection_slug: connection_slug
      )

      render json: {
        data: {
          plan_json: result.plan_json,
          estimated_cost: result.estimated_cost,
          warnings: result.warnings || []
        }
      }, status: :ok
    rescue Prism::QueryError => e
      render json: { errors: [e.message] }, status: :bad_request
    end
  end
end