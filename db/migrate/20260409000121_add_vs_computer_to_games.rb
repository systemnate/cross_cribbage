class AddVsComputerToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :vs_computer, :boolean, default: false, null: false
  end
end
