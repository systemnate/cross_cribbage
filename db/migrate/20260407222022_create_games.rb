class CreateGames < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :games, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string  :status,                   default: "waiting", null: false
      t.string  :current_turn
      t.string  :crib_owner
      t.integer :round,                    default: 1,         null: false
      t.string  :winner_slot

      t.string  :player1_token,            null: false
      t.string  :player2_token

      t.jsonb   :player1_deck,             default: [],        null: false
      t.jsonb   :player2_deck,             default: [],        null: false
      t.jsonb   :crib,                     default: [],        null: false

      t.jsonb   :board,                    default: [],        null: false
      t.jsonb   :starter_card

      t.jsonb   :row_scores,               default: [nil, nil, nil, nil, nil], null: false
      t.jsonb   :col_scores,               default: [nil, nil, nil, nil, nil], null: false
      t.integer :crib_score

      t.integer :player1_peg,              default: 0,         null: false
      t.integer :player2_peg,              default: 0,         null: false

      t.integer :player1_crib_discards,    default: 0,         null: false
      t.integer :player2_crib_discards,    default: 0,         null: false

      t.timestamps
    end

    add_index :games, :player1_token, unique: true
    add_index :games, :player2_token, unique: true, where: "player2_token IS NOT NULL"
    add_index :games, :status
  end
end
