class SimplifyUserRoles < ActiveRecord::Migration[8.0]
  def up
    # Map existing roles to new simplified roles:
    # owner_admin (0) -> admin (0)
    # data_engineer (1) -> admin (0)
    # analyst (2) -> admin (0)
    # viewer (3) -> viewer (1)
    # support (4) -> viewer (1)

    # Update all data_engineers and analysts to admin (0)
    execute <<-SQL
      UPDATE users SET role = 0 WHERE role IN (1, 2);
    SQL

    # Update all support users to viewer (1)
    execute <<-SQL
      UPDATE users SET role = 1 WHERE role = 4;
    SQL

    # Update existing viewers (3) to new viewer value (1)
    execute <<-SQL
      UPDATE users SET role = 1 WHERE role = 3;
    SQL

    # Change default value from 3 to 1
    change_column_default :users, :role, from: 3, to: 1
  end

  def down
    # Reverse migration - map back to original values
    # This is lossy since we can't distinguish between original role types
    # admin (0) stays as owner_admin (0)
    # viewer (1) -> viewer (3)

    execute <<-SQL
      UPDATE users SET role = 3 WHERE role = 1;
    SQL

    # Change default value back
    change_column_default :users, :role, from: 1, to: 3
  end
end
