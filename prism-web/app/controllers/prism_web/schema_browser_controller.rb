module PrismWeb
  class SchemaBrowserController < ApplicationController
    before_action :set_connection_slug, only: [:schema, :tables]

    def index
      @connection_slug ||= Prism.config.connections.default_slug&.to_s
      respond_to do |format|
        format.html { render :index }
        format.json { schema }
      end
    end

    def schema
      tables = schema_inspector.tables(@connection_slug, owner: Current.owner)
      respond_to do |format|
        format.json do
          render json: { data: tables.map { |table_name| { name: table_name } } },
                 status: :ok
        end
        format.html { render partial: "table_list", locals: { tables: tables } }
      end
    end

    def tables
      table_name = params[:table]

      @table_schema = build_table_schema(@connection_slug, table_name)

      respond_to do |format|
        format.html { render :show }
        format.json do
          render json: { data: @table_schema }, status: :ok
        end
      end
    end

    private

    def set_connection_slug
      @connection_slug = params[:slug].presence || params[:connection_slug].presence
      @connection_slug ||= Prism.config.connections.default_slug&.to_s
    end

    def build_table_schema(connection_slug, table_name)
      owner = Current.owner
      {
        name: table_name,
        columns: schema_inspector.columns(connection_slug, table_name, owner: owner),
        indexes: schema_inspector.indexes(connection_slug, table_name, owner: owner),
        foreign_keys: schema_inspector.foreign_keys(connection_slug, [table_name], owner: owner),
        sample_rows: schema_inspector.sample_rows(connection_slug, table_name, owner: owner)
      }
    end
  end
end