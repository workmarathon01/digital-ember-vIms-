class CreateVisitorMovements < ActiveRecord::Migration[8.1]
  def up
    create_table :visitor_movements do |t|
      t.references :visitor, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.string :direction, null: false
      t.datetime :occurred_at, null: false
      t.string :source, null: false, default: "staff"
      t.string :ip_address
      t.timestamps
    end

    add_index :visitor_movements, [ :visitor_id, :occurred_at ]
    add_index :visitor_movements, [ :visitor_id, :direction ]
    add_check_constraint :visitor_movements,
                         "direction IN ('in', 'out')",
                         name: "visitor_movements_direction_check"

    # Visitors who are currently inside have no history yet. Seed an open
    # inbound movement so they can still be checked out after this migration.
    execute <<~SQL.squish
      INSERT INTO visitor_movements
        (visitor_id, direction, occurred_at, source, created_at, updated_at)
      SELECT id, 'in',
             COALESCE(qr_checked_in_at, updated_at, created_at, CURRENT_TIMESTAMP),
             'system', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM visitors
      WHERE visitor_in_out = 'IN'
    SQL
  end

  def down
    drop_table :visitor_movements
  end
end
