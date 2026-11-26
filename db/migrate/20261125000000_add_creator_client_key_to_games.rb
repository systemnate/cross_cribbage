# frozen_string_literal: true

class AddCreatorClientKeyToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :creator_client_key, :string
    add_index :games, [:creator_client_key, :status]
  end
end
