class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 3  # Default to 'viewer' role
      t.string :name, null: false

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
