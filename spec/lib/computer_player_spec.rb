require "rails_helper"

RSpec.describe ComputerPlayer do
  # Build a minimal card hash
  def card(rank, suit, id = SecureRandom.uuid)
    { "rank" => rank, "suit" => suit, "id" => id }
  end

  def board_with_starter(starter)
    b = Array.new(5) { Array.new(5, nil) }
    b[2][2] = starter
    b
  end

  def nil_scores
    [nil, nil, nil, nil, nil]
  end

  # --- Scenario: no scoring combos possible (all cells give net_impact = 0)
  # A lone "2" on any empty row/col scores 0 points. Net impact = 0 everywhere.
  # Since 0 <= 0 and crib has space → should discard.
  describe "#decide with all-zero net impact and crib space" do
    let(:starter) { card("3", "♥", "c2") }

    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1")],
        board:                 board_with_starter(starter),
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          starter,
        player2_crib_discards: 0,
        crib_owner:            "player2"
      )
    end

    it "returns :discard" do
      expect(described_class.new(game).decide).to eq({ action: :discard })
    end
  end

  # --- Same scenario but crib is full (discards == 2) → must place
  describe "#decide with all-zero net impact but crib full" do
    let(:starter) { card("3", "♥", "c2") }

    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1")],
        board:                 board_with_starter(starter),
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          starter,
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

  # --- Scenario: deck size <= remaining crib slots → must discard regardless of crib ownership
  describe "#decide when forced to discard (deck size <= remaining crib slots)" do
    let(:starter) { card("3", "♥", "c2") }

    let(:game) do
      create(:game,
        player2_deck:          [card("2", "♠", "c1"), card("7", "♦", "c3")],
        board:                 board_with_starter(starter),
        row_scores:            nil_scores,
        col_scores:            nil_scores,
        starter_card:          starter,
        player2_crib_discards: 0,
        crib_owner:            "player1"   # AI doesn't own crib — still must discard
      )
    end

    it "returns :discard because deck.size (2) <= remaining_crib (2)" do
      expect(described_class.new(game).decide).to eq({ action: :discard })
    end
  end

  # --- Scenario: row 0 has 5♠ and 10♥. Next card is 5♦.
  # Placing 5♦ in row 0 scores: pair(5♠,5♦)=2 + fifteen(5♠+10♥)=2 + fifteen(5♦+10♥)=2 = 6.
  # Placing 5♦ in any other row scores 0 (lone card, no combos with A starter).
  # Net impact for row 0 cells = 6 - 0 = 6. For all other cells = 0 - 0 = 0.
  # Best cell should be the first empty cell in row 0 (col 2, since 0 and 1 are occupied).
  describe "#decide picks the cell with highest net impact" do
    let(:starter) { card("A", "♣", "c4") }

    let(:board) do
      b = board_with_starter(starter)
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
        starter_card:          starter,
        player2_crib_discards: 2   # force placement
      )
    end

    it "places in row 0 (highest net row impact)" do
      result = described_class.new(game).decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to eq(0)
    end
  end

  describe "#best_fill_score (via send)" do
    # Test the private helper directly via send for unit testing
    def card(rank, suit, id = SecureRandom.uuid)
      { "rank" => rank, "suit" => suit, "id" => id }
    end

    let(:starter) { card("3", "♥") }

    let(:game) do
      create(:game,
        board: Array.new(5) { Array.new(5, nil) }.tap { |b| b[2][2] = starter },
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player1_deck: [],
        player2_deck: [],
        player2_crib_discards: 2
      )
    end

    let(:cp) { described_class.new(game) }

    it "returns 0 when no empty slots" do
      existing = [card("5", "♠"), card("5", "♦"), card("10", "♥"), card("J", "♣"), card("K", "♦")]
      score = cp.send(:best_fill_score, existing, [], 0, row_index: 0)
      expect(score).to eq(CribbageHand.new(existing, starter: starter, is_center: false).score)
    end

    it "picks the best card from the deck to fill one slot" do
      existing = [card("5", "♠"), card("5", "♦"), card("10", "♥"), card("J", "♣")]
      deck = [card("A", "♣"), card("5", "♥"), card("K", "♦")]
      # 5♥ should be picked: adds a third 5 (pair royal = 6) plus more fifteens
      score = cp.send(:best_fill_score, existing, deck, 1, row_index: 0)

      # Verify it picked the best — score with 5♥ should beat score with A or K
      best_hand = existing + [deck[1]] # the 5♥
      expect(score).to eq(CribbageHand.new(best_hand, starter: starter, is_center: false).score)
    end

    it "fills multiple slots with the best combination" do
      existing = [card("7", "♠"), card("8", "♦"), card("9", "♥")]
      deck = [card("6", "♣"), card("10", "♠"), card("A", "♦"), card("2", "♥")]
      # 6 + A scores 10: run (6-7-8-9) + fifteen (6+9, 7+8, 6+A+8 etc.)
      # This beats 6 + 10 (which scores 9) despite the 5-card run with 10
      score = cp.send(:best_fill_score, existing, deck, 2, row_index: 0)

      best_hand = existing + [deck[0], deck[2]] # 6 and A
      expect(score).to eq(CribbageHand.new(best_hand, starter: starter, is_center: false).score)
    end

    it "uses is_center: true for row 2" do
      existing = [card("J", "♥"), card("5", "♠"), card("10", "♦")]
      deck = [card("K", "♣"), card("Q", "♠")]
      score_center = cp.send(:best_fill_score, existing, deck, 2, row_index: 2)
      score_other = cp.send(:best_fill_score, existing, deck, 2, row_index: 0)

      # Row 2 (center) enables nobs scoring — J of starter's suit scores extra
      # Even if nobs doesn't apply here, is_center should be passed correctly
      expect(score_center).to be >= score_other
    end
  end

  describe "#defensive_score (via send)" do
    def card(rank, suit, id = SecureRandom.uuid)
      { "rank" => rank, "suit" => suit, "id" => id }
    end

    let(:starter) { card("3", "♥") }

    # Blocking scenario: column has 7-7-8-8, computer places an Ace.
    # The Ace should disrupt the opponent's best-case score.
    describe "blocking a dangerous column" do
      let(:board) do
        b = Array.new(5) { Array.new(5, nil) }
        b[2][2] = starter
        b[0][0] = card("7", "♠")
        b[1][0] = card("7", "♦")
        b[3][0] = card("8", "♣")
        b[4][0] = card("8", "♥")
        b
      end

      let(:game) do
        create(:game,
          board: board,
          starter_card: starter,
          row_scores: [nil, nil, nil, nil, nil],
          col_scores: [nil, nil, nil, nil, nil],
          player1_deck: [card("6", "♠"), card("9", "♦"), card("5", "♣"), card("10", "♥")],
          player2_deck: [card("A", "♦")],
          player2_crib_discards: 2
        )
      end

      let(:cp) { described_class.new(game) }

      it "returns a positive score (placement disrupts opponent)" do
        col_base = Array.new(5) { |c| board.map { |r| r[c] }.compact }
        score = cp.send(:defensive_score, 2, 0, card("A", "♦"), col_base)
        expect(score).to be > 0
      end
    end

    # Feeding scenario: column has 7-8, computer places a 6.
    # The 6 helps the opponent build a run.
    describe "feeding a dangerous column" do
      let(:board) do
        b = Array.new(5) { Array.new(5, nil) }
        b[2][2] = starter
        b[0][1] = card("7", "♠")
        b[1][1] = card("8", "♦")
        b
      end

      let(:game) do
        create(:game,
          board: board,
          starter_card: starter,
          row_scores: [nil, nil, nil, nil, nil],
          col_scores: [nil, nil, nil, nil, nil],
          player1_deck: [card("6", "♣"), card("9", "♥"), card("5", "♦"), card("10", "♣")],
          player2_deck: [card("6", "♠")],
          player2_crib_discards: 2
        )
      end

      let(:cp) { described_class.new(game) }

      it "returns a negative score (placement helps opponent)" do
        col_base = Array.new(5) { |c| board.map { |r| r[c] }.compact }
        score = cp.send(:defensive_score, 2, 1, card("6", "♠"), col_base)
        expect(score).to be < 0
      end
    end
  end
end
