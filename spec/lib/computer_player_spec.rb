require "rails_helper"

RSpec.describe ComputerPlayer do
  # Build a minimal card hash
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  def empty_board
    Array.new(5) { Array.new(5, nil) }
  end

  def nil_scores
    [nil, nil, nil, nil, nil]
  end

  # --- Scenario: no scoring combos possible (all cells give net_impact = 0)
  # A lone "2" on any empty row/col scores 0 points. Net impact = 0 everywhere.
  # Since 0 <= 0 and crib has space → should discard.
  describe "#decide with all-zero net impact and crib space" do
    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1")],
        board:                 empty_board,
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          card("3", "♥", "c2"),
        player2_crib_discards: 0
      )
    end

    it "returns :discard" do
      expect(described_class.new(game).decide).to eq({ action: :discard })
    end
  end

  # --- Same scenario but crib is full (discards == 2) → must place
  describe "#decide with all-zero net impact but crib full" do
    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1")],
        board:                 empty_board,
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          card("3", "♥", "c2"),
        player2_crib_discards: 2
      )
    end

    it "returns :place with a valid empty cell" do
      result = described_class.new(game).decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to be_between(0, 4)
      expect(result[:col]).to be_between(0, 4)
    end
  end

  # --- Scenario: row 0 has 5♠ and 10♥. Next card is 5♦.
  # Placing 5♦ in row 0 scores: pair(5♠,5♦)=2 + fifteen(5♠+10♥)=2 + fifteen(5♦+10♥)=2 = 6.
  # Placing 5♦ in any other row scores 0 (lone card, no combos with A starter).
  # Net impact for row 0 cells = 6 - 0 = 6. For all other cells = 0 - 0 = 0.
  # Best cell should be the first empty cell in row 0 (col 2, since 0 and 1 are occupied).
  describe "#decide picks the cell with highest net impact" do
    let(:board) do
      b = empty_board
      b[0][0] = card("5", "♠", "c1")
      b[0][1] = card("10", "♥", "c2")
      b
    end

    let(:game) do
      create(:game,
        player2_deck:          [card("5", "♦", "c3")],
        board:                 board,
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          card("A", "♣", "c4"),
        player2_crib_discards: 2   # force placement
      )
    end

    it "places in row 0 (highest net row impact)" do
      result = described_class.new(game).decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to eq(0)
    end
  end
end
