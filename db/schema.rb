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

ActiveRecord::Schema[8.0].define(version: 2026_04_08_001000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "games", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "status", default: "waiting", null: false
    t.string "current_turn"
    t.string "crib_owner"
    t.integer "round", default: 1, null: false
    t.string "winner_slot"
    t.string "player1_token", null: false
    t.string "player2_token"
    t.jsonb "player1_deck", default: [], null: false
    t.jsonb "player2_deck", default: [], null: false
    t.jsonb "crib", default: [], null: false
    t.jsonb "board", default: [], null: false
    t.jsonb "starter_card"
    t.jsonb "row_scores", default: [nil, nil, nil, nil, nil], null: false
    t.jsonb "col_scores", default: [nil, nil, nil, nil, nil], null: false
    t.integer "crib_score"
    t.integer "player1_peg", default: 0, null: false
    t.integer "player2_peg", default: 0, null: false
    t.integer "player1_crib_discards", default: 0, null: false
    t.integer "player2_crib_discards", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "player1_confirmed_scoring", default: false, null: false
    t.boolean "player2_confirmed_scoring", default: false, null: false
    t.index ["player1_token"], name: "index_games_on_player1_token", unique: true
    t.index ["player2_token"], name: "index_games_on_player2_token", unique: true, where: "(player2_token IS NOT NULL)"
    t.index ["status"], name: "index_games_on_status"
  end
end
