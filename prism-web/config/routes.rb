PrismWeb::Engine.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'connections/:slug/schema', to: 'schema_browser#schema', as: :connection_schema
      get 'connections/:slug/tables/:table', to: 'schema_browser#tables', as: :connection_table
      
      post 'queries/validate', to: 'queries#validate', as: :validate_query
      post 'queries/execute', to: 'queries#execute', as: :execute_query
      post 'queries/explain', to: 'queries#explain', as: :explain_query
      
      resources :saved_queries, only: [:index, :show, :create, :update, :destroy] do
        post 'execute', on: :member
      end
      
      resources :dashboards, only: [:index, :show, :create, :update, :destroy] do
        resources :widgets, only: [:create, :update, :destroy, :show]
      end
      
      resources :ai_conversations, only: [:index, :show, :create, :update, :destroy] do
        post 'messages', on: :member
      end
    end
  end

  root to: 'schema_browser#index'

  get '/share/:token', to: 'shares#show', as: 'share'
  get '/share/:token/data', to: 'shares#data', as: 'share_data'
end