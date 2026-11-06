module PrismWeb
  class SavedQueriesController < ApplicationController
    before_action :set_saved_query, only: [:show, :edit, :update, :destroy, :execute]

    def index
      @saved_queries = SavedQuery.accessible_by_owner(Current.owner).order(created_at: :desc)
      render :index
    end

    def show
      render :show
    end

    def new
      @saved_query = SavedQuery.new
      render :new
    end

    def create
      @saved_query = SavedQuery.new(saved_query_params)
      @saved_query.owner_type = Current.owner[:type]
      @saved_query.owner_id = Current.owner[:id]

      if @saved_query.save
        redirect_to prism_web.saved_query_path(@saved_query), notice: "Saved query created successfully"
      else
        render :new
      end
    end

    def edit
      render :edit
    end

    def update
      if @saved_query.update(saved_query_params)
        redirect_to prism_web.saved_query_path(@saved_query), notice: "Saved query updated successfully"
      else
        render :edit
      end
    end

    def destroy
      @saved_query.destroy
      redirect_to prism_web.saved_queries_path, notice: "Saved query deleted successfully"
    end

    def execute
      variables = params[:variables] || {}

      begin
        result = query_engine.execute(
          @saved_query.sql,
          variables: variables,
          connection_slug: @saved_query.connection_slug
        )

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
            variables: @saved_query.variables
          }
        }, status: :ok
      rescue Prism::QueryError => e
        render json: { errors: [e.message] }, status: :bad_request
      end
    end

    private

    def set_saved_query
      @saved_query = SavedQuery.find(params[:id])

      unless @saved_query.accessible_by_owner?(Current.owner)
        render json: { errors: ["Access denied"] }, status: :forbidden
      end
    end

    def saved_query_params
      params.require(:saved_query).permit(
        :name,
        :sql,
        :description,
        :visibility,
        :connection_slug,
        variables: {}
      )
    end
  end
end