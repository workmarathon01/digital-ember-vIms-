class AddEmployeeRegistrationToUsers < ActiveRecord::Migration[8.1]
  def change
    # Existing accounts were created by an administrator, so they are already
    # approved. Only self-registered employee accounts start as "pending".
    add_column :users, :registration_status, :string, null: false, default: "approved"
    add_column :users, :registration_submitted_at, :datetime
    add_column :users, :reviewed_at, :datetime
    add_column :users, :reviewed_by_id, :bigint
    add_column :users, :registration_note, :text

    add_index :users, :registration_status
    add_index :users, :reviewed_by_id
  end
end
