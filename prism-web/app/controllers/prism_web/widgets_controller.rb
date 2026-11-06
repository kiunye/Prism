module PrismWeb
  class WidgetsController < ApplicationController
    before_action :set_dashboard
    before_action :set_widget, only: [:update, :destroy, :show]

    def create
      @widget = @dashboard.widgets.new(widget_params)

      if @widget.save
        render json: { data: @widget }, status: :created
      else
        render json: { errors: @widget.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def show
      begin
        result = widget_data(@widget)
        render json: { data: result }, status: :ok
      rescue Prism::QueryError => e
        render json: { errors: [e.message] }, status: :bad_request
      end
    end

    def update
      if @widget.update(widget_params)
        render json: { data: @widget }, status: :ok
      else
        render json: { errors: @widget.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @widget.destroy
      head :no_content
    end

    private

    def widget_data(widget)
      return { error: "No saved query" } unless widget.saved_query_id

      saved_query = SavedQuery.find(widget.saved_query_id)
      result = query_engine.execute(
        saved_query.sql,
        variables: {},
        connection_slug: saved_query.connection_slug
      )

      {
        columns: result.columns,
        rows: result.rows,
        row_count: result.row_count,
        chart_type: widget.chart_type
      }
    end

    def set_dashboard
      @dashboard = Dashboard.find(params[:dashboard_id])

      unless @dashboard.owner_type == Current.owner[:type] && @dashboard.owner_id == Current.owner[:id]
        render json: { errors: ["Access denied"] }, status: :forbidden
      end
    end

    def set_widget
      @widget = @dashboard.widgets.find(params[:id])
    end

    def widget_params
      params.require(:widget).permit(
        :name,
        :chart_type,
        :saved_query_id,
        :grid_x,
        :grid_y,
        :grid_w,
        :grid_h,
        options: {},
        refresh_interval: {}
      )
    end
  end
end