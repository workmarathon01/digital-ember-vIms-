class CreatePushTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :push_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, limit: 2048, null: false
      t.string :uuid, null: false
      t.string :platform, null: false, default: "unknown"
      t.string :device_name
      t.string :app_version
      t.string :os_version
      t.string :locale
      t.string :timezone
      t.boolean :enabled, null: false, default: true
      t.datetime :last_seen_at, null: false
      t.datetime :disabled_at
      t.string :last_error
      t.integer :failed_count, null: false, default: 0
      t.timestamps
    end

    # A device uuid identifies one installation. An FCM token identifies one
    # installation too, so both must be globally unique. Re-registration moves
    # the row instead of creating duplicates.
    add_index :push_tokens, :uuid, unique: true
    add_index :push_tokens, :token, unique: true
    add_index :push_tokens, [ :user_id, :enabled ]
    add_index :push_tokens, :last_seen_at
  end
end
