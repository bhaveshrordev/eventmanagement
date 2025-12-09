class CreateEventVoteTallies < ActiveRecord::Migration[7.1]
  def change
    create_table :event_vote_tallies do |t|
      t.references :event, null: false, foreign_key: { to_table: :events }
      t.integer :upvotes_count, null: false, default: 0
      t.integer :downvotes_count, null: false, default: 0
      t.timestamps
    end

  end
end
