class AddScoringConfirmationsToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :player1_confirmed_scoring, :boolean, default: false, null: false
    add_column :games, :player2_confirmed_scoring, :boolean, default: false, null: false
  end
end
