class PrismSetUp < ActiveRecord::Migration[8.0]
  def change
    create_table :prism_saved_queries do |t|
      t.string :name, null: false
      t.text :sql, null: false
      t.jsonb :variables
      t.text :description
      t.string :visibility, default: "owner"
      t.string :owner_type
      t.bigint :owner_id
      t.string :connection_slug
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [ :owner_type, :owner_id ]
      t.index :name
    end

    create_table :prism_dashboards do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :grid_layout
      t.jsonb :filters
      t.string :owner_type
      t.bigint :owner_id
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [ :owner_type, :owner_id ]
    end

    create_table :prism_widgets do |t|
      t.string :name, null: false
      t.jsonb :options
      t.bigint :dashboard_id, null: false
      t.bigint :saved_query_id
      t.string :chart_type
      t.jsonb :refresh_interval
      t.integer :grid_x
      t.integer :grid_y
      t.integer :grid_w
      t.integer :grid_h
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [ :dashboard_id ]
      t.index [ :saved_query_id ]
    end

    create_table :prism_ai_conversations do |t|
      t.string :title
      t.text :context
      t.jsonb :messages
      t.string :owner_type
      t.bigint :owner_id
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [ :owner_type, :owner_id ]
    end

    create_table :prism_share_tokens do |t|
      t.string :token, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id, null: false
      t.string :owner_type
      t.bigint :owner_id
      t.datetime :expires_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index :token, unique: true
      t.index [ :resource_type, :resource_id ]
    end

    create_table :prism_query_cache do |t|
      t.string :cache_key, null: false
      t.jsonb :query_result
      t.datetime :expires_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index :cache_key, unique: true
    end
  end
end