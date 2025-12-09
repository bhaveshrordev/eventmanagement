class CreateEventVotes < ActiveRecord::Migration[7.1]
  def change
    create_table :event_votes do |t|
      t.references :event, null: false, foreign_key: { to_table: :events }
      t.string :user_id, null: false
      t.string :vote, null: false # 'up' or 'down'
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :event_votes, [:event_id, :user_id], unique: true, name: 'index_event_votes_on_event_id_and_user_id'
  end
end
