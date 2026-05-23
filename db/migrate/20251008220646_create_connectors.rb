class CreateConnectors < ActiveRecord::Migration[8.0]
  def change
    create_table :connectors do |t|
      t.string :name, null: false
      t.string :connector_type, null: false, default: "snowflake"
      t.jsonb :config, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.datetime :last_checked_at

      t.timestamps
    end

    add_index :connectors, :name
    add_index :connectors, :status
  end
end
