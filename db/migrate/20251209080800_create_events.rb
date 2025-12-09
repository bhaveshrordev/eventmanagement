class CreateEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :events do |t|
      t.string  :external_id, null: false
      t.string  :title, null: false
      t.text    :description
      t.datetime :starts_at
      t.datetime :ends_at
      t.string  :image_url
      t.string  :url
      t.string  :branded_url
      t.boolean :availability, default: true
      t.string  :published_state
      t.string  :object_kind

      t.jsonb :organiser
      t.jsonb :minimum_price
      t.jsonb :categorization
      t.jsonb :location
      
      t.timestamps
    end

    add_index :events, :external_id, unique: true
    add_index :events, :starts_at
    add_index :events, :availability
    add_index :events, :location, using: :gin
  end
end

