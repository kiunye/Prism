module PrismWeb
  class SavedQueriesController < ApplicationController
    before_action :set_saved_query, only: [:show, :update, :destroy, :execute]

    def index
      render json: { data: SavedQuery.accessible_by_owner(Current.owner).order(created_at: :desc) }
    end

    def show
      render json: { data: @saved_query }
    end

    def create
      saved_query = SavedQuery.new(saved_query_params)
      saved_query.owner_type = Current.owner[:type]
      saved_query.owner_id = Current.owner[:id]

      if saved_query.save
        render json: { data: saved_query }, status: :created
      else
        render json: { errors: saved_query.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      if @saved_query.update(saved_query_params)
        render json: { data: @saved_query }
      else
        render json: { errors: @saved_query.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @saved_query.destroy
      head :no_content
    end

    def execute
      result = query_engine.execute(
        @saved_query.sql,
        variables: adhoc_variables(@saved_query.sql),
        values: params[:variables]&.to_unsafe_h || {},
        connection_slug: @saved_query.connection_slug
      )

      render json: {
        data: { rows: result.rows, columns: result.columns },
        meta: {
          row_count: result.row_count,
          duration_ms: result.duration_ms,
          query_id: result.query_id,
          connection_slug: result.connection_slug
        }
      }
    rescue Prism::QueryError => e
      render json: { errors: [e.message] }, status: :bad_request
    end

    private

    def set_saved_query
      @saved_query = SavedQuery.find(params[:id])

      render json: { errors: ["Access denied"] }, status: :forbidden unless @saved_query.accessible_by_owner?(Current.owner)
    end

    def saved_query_params
      params.require(:saved_query).permit(:name, :sql, :description, :visibility, :connection_slug, variables: {})
    end
  end
end
