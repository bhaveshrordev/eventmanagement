# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_12_09_080800) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "events", force: :cascade do |t|
    t.string "external_id", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "image_url"
    t.string "url"
    t.string "branded_url"
    t.boolean "availability", default: true
    t.string "published_state"
    t.string "object_kind"
    t.jsonb "organiser"
    t.jsonb "minimum_price"
    t.jsonb "categorization"
    t.jsonb "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["availability"], name: "index_events_on_availability"
    t.index ["external_id"], name: "index_events_on_external_id", unique: true
    t.index ["location"], name: "index_events_on_location", using: :gin
    t.index ["starts_at"], name: "index_events_on_starts_at"
  end

end
