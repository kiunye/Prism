PrismWeb::Engine.routes.draw do
  scope "api/v1", as: :api_v1 do
    get "connections/:slug/schema", to: "schema_browser#schema", as: :connection_schema
    get "connections/:slug/tables/:table", to: "schema_browser#tables", as: :connection_table

    post "queries/validate", to: "queries#validate", as: :validate_query
    post "queries/execute", to: "queries#execute", as: :execute_query
    post "queries/explain", to: "queries#explain", as: :explain_query

    resources :saved_queries, only: %i[ index show create update destroy ] do
      post "execute", on: :member
    end

    resources :dashboards, only: %i[ index show create update destroy ] do
      resources :widgets, only: %i[ create update destroy show ]
    end

    resources :ai_conversations, only: %i[ index show create update destroy ] do
      post "messages", on: :member
    end
  end

  root to: "schema_browser#index"

  get "/queries/new", to: "queries#new", as: :new_query

  get "/share/:token", to: "shares#show", as: :share
  get "/share/:token/data", to: "shares#data", as: :share_data
end
