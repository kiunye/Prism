module PrismWeb
  class DashboardsController < ApplicationController
    before_action :set_dashboard, only: [:show, :edit, :update, :destroy]

    def index
      @dashboards = Dashboard.where(
        owner_type: Current.owner[:type],
        owner_id: Current.owner[:id]
      ).order(created_at: :desc)
      render :index
    end

    def show
      render :show
    end

    def new
      @dashboard = Dashboard.new
      render :new
    end

    def create
      @dashboard = Dashboard.new(dashboard_params)
      @dashboard.owner_type = Current.owner[:type]
      @dashboard.owner_id = Current.owner[:id]

      if @dashboard.save
        redirect_to prism_web.dashboard_path(@dashboard), notice: "Dashboard created successfully"
      else
        render :new
      end
    end

    def edit
      render :edit
    end

    def update
      if @dashboard.update(dashboard_params)
        redirect_to prism_web.dashboard_path(@dashboard), notice: "Dashboard updated successfully"
      else
        render :edit
      end
    end

    def destroy
      @dashboard.destroy
      redirect_to prism_web.dashboards_path, notice: "Dashboard deleted successfully"
    end

    private

    def set_dashboard
      @dashboard = Dashboard.find(params[:id])

      unless @dashboard.owner_type == Current.owner[:type] && @dashboard.owner_id == Current.owner[:id]
        render json: { errors: ["Access denied"] }, status: :forbidden
      end
    end

    def dashboard_params
      params.require(:dashboard).permit(
        :name,
        :description,
        grid_layout: [],
        filters: {}
      )
    end
  end
end