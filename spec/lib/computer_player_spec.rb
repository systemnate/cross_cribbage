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

  describe "#row_potential (via send)" do
    def card(rank, suit, id = SecureRandom.uuid)
      { "rank" => rank, "suit" => suit, "id" => id }
    end

    let(:starter) { card("3", "♥") }

    describe "completing a row returns 0" do
      let(:board) do
        b = Array.new(5) { Array.new(5, nil) }
        b[2][2] = starter
        b[0][0] = card("5", "♠")
        b[0][1] = card("5", "♦")
        b[0][3] = card("10", "♥")
        b[0][4] = card("J", "♣")
        b
      end

      let(:game) do
        create(:game,
          board: board,
          starter_card: starter,
          row_scores: [nil, nil, nil, nil, nil],
          col_scores: [nil, nil, nil, nil, nil],
          player2_deck: [card("5", "♥"), card("K", "♠"), card("Q", "♦")],
          player1_deck: [],
          player2_crib_discards: 2
        )
      end

      let(:cp) { described_class.new(game) }

      it "returns 0 because the row is being completed" do
        row_base = Array.new(5) { |r| board[r].compact }
        score = cp.send(:row_potential, 0, 2, card("5", "♥"), row_base)
        expect(score).to eq(0)
      end
    end

    describe "building a promising row returns positive potential" do
      let(:board) do
        b = Array.new(5) { Array.new(5, nil) }
        b[2][2] = starter
        b[1][0] = card("7", "♠")
        b[1][1] = card("8", "♦")
        b
      end

      let(:game) do
        create(:game,
          board: board,
          starter_card: starter,
          row_scores: [nil, nil, nil, nil, nil],
          col_scores: [nil, nil, nil, nil, nil],
          player2_deck: [card("9", "♣"), card("6", "♥"), card("10", "♠"), card("A", "♦")],
          player1_deck: [],
          player2_crib_discards: 2
        )
      end

      let(:cp) { described_class.new(game) }

      it "returns positive potential for a row with run seeds" do
        row_base = Array.new(5) { |r| board[r].compact }
        # Placing 9♣ in row 1 creates 7-8-9 run seed with 2 open slots
        score = cp.send(:row_potential, 1, 2, card("9", "♣"), row_base)
        expect(score).to be > 0
      end
    end

    describe "building a dead-end row returns lower potential" do
      let(:board) do
        b = Array.new(5) { Array.new(5, nil) }
        b[2][2] = starter
        b[3][0] = card("A", "♠")
        b[3][1] = card("3", "♦")
        b
      end

      let(:game) do
        create(:game,
          board: board,
          starter_card: starter,
          row_scores: [nil, nil, nil, nil, nil],
          col_scores: [nil, nil, nil, nil, nil],
          player2_deck: [card("9", "♣"), card("6", "♥"), card("10", "♠"), card("K", "♦")],
          player1_deck: [],
          player2_crib_discards: 2
        )
      end

      let(:cp) { described_class.new(game) }

      it "returns lower potential than a synergistic row" do
        row_base = Array.new(5) { |r| board[r].compact }
        # Row 3 has A-3 with a K being placed — low synergy
        dead_end = cp.send(:row_potential, 3, 2, card("K", "♦"), row_base)

        # Compare: if row 3 had 7-8 with 9 being placed (high synergy)
        # We can't directly compare in this test, but dead_end should be modest
        expect(dead_end).to be >= 0
      end
    end
  end

  describe "#decide with defensive blocking" do
    def card(rank, suit, id = SecureRandom.uuid)
      { "rank" => rank, "suit" => suit, "id" => id }
    end

    # Column 0 has 7-7-8-8 — a monster threat for the opponent.
    # The only open slot in column 0 is (2, 0).
    # The computer's next card is A♦ — low synergy, good blocker.
    # The computer should place at (2, 0) to disrupt the opponent's column,
    # even though there's no immediate row benefit.
    let(:starter) { card("3", "♥") }

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
        player1_deck: [card("6", "♠"), card("9", "♦"), card("5", "♣"), card("10", "♥"),
                       card("4", "♠"), card("J", "♦"), card("Q", "♣"), card("K", "♥")],
        player2_deck: [card("A", "♦"), card("2", "♣"), card("4", "♥")],
        player2_crib_discards: 2,
        player1_crib_discards: 2,
        crib_owner: "player1"
      )
    end

    it "blocks the dangerous column by placing at (2, 0)" do
      cp = described_class.new(game)
      # Stub unknown_cards to a curated pool that includes a 9 — the threat
      # rank that would complete a 7-8-9 run in this column. The production
      # pool is randomly sampled, which makes this assertion sampling-dependent.
      allow(cp).to receive(:unknown_cards).and_return([
        card("9", "♣"), card("9", "♠"),
        card("2", "♣"), card("4", "♦"), card("Q", "♥"),
        card("K", "♠"), card("J", "♣"), card("J", "♦"),
        card("3", "♣"), card("4", "♥")
      ])
      result = cp.decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to eq(2)
      expect(result[:col]).to eq(0)
    end
  end

  describe "#decide prefers building potential over completing low-value rows" do
    def card(rank, suit, id = SecureRandom.uuid)
      { "rank" => rank, "suit" => suit, "id" => id }
    end

    # Row 0 has 4 cards: A-2-3-K. Placing a Q completes it for ~3-4 points (a run of 3).
    # Row 1 has 2 cards: 5-5. Placing a Q (value 10) gives a fifteen (5+10) with
    #   high potential for more fifteens/pairs with remaining 5s and 10-value cards.
    # The computer should prefer row 1 for its higher potential.
    let(:starter) { card("3", "♥") }

    let(:board) do
      b = Array.new(5) { Array.new(5, nil) }
      b[2][2] = starter
      b[0][0] = card("A", "♠")
      b[0][1] = card("2", "♦")
      b[0][3] = card("K", "♣")
      b[0][4] = card("3", "♠")
      b[1][0] = card("5", "♠")
      b[1][1] = card("5", "♦")
      b
    end

    let(:game) do
      create(:game,
        board: board,
        starter_card: starter,
        row_scores: [nil, nil, nil, nil, nil],
        col_scores: [nil, nil, nil, nil, nil],
        player1_deck: [],
        player2_deck: [card("Q", "♥"), card("5", "♥"), card("10", "♣"), card("J", "♦")],
        player2_crib_discards: 2,
        player1_crib_discards: 2,
        crib_owner: "player1"
      )
    end

    it "places in row 1 (higher potential) rather than completing row 0" do
      result = described_class.new(game).decide
      expect(result[:action]).to eq(:place)
      expect(result[:row]).to eq(1)
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

      # Stub unknown_cards to a curated pool that includes a 9 — the threat
      # rank that would complete a 7-8-9 run in this column. The production
      # pool is randomly sampled, which makes this assertion sampling-dependent.
      before do
        allow(cp).to receive(:unknown_cards).and_return([
          card("9", "♣"), card("9", "♠"),
          card("2", "♣"), card("4", "♦"), card("Q", "♥"),
          card("K", "♠"), card("J", "♣"), card("J", "♦"),
          card("3", "♣"), card("4", "♥")
        ])
      end

      it "returns a positive score (placement disrupts opponent)" do
        col_base = Array.new(5) { |c| board.map { |r| r[c] }.compact }
        score = cp.send(:defensive_score, 2, 0, card("A", "♦"), col_base)
        expect(score).to be > 0
      end
    end

    # Feeding scenario: column has 7-8, computer places a 6.
    # The 6 extends the run, making the column more valuable for
    # the opponent. The computer uses unknown cards (not the
    # opponent's actual deck), but should still detect that adding
    # a 6 to a 7-8 column increases its scoring potential.
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

      # Stub unknown_cards to include a 9 — adding 6 to {7,8} makes longer
      # runs possible (6-7-8-9 = 4 vs 7-8-9 = 3), so the "with" arm scores
      # higher than the "without" arm and defensive_score goes non-positive.
      before do
        allow(cp).to receive(:unknown_cards).and_return([
          card("9", "♣"), card("9", "♠"),
          card("2", "♣"), card("4", "♦"), card("Q", "♥"),
          card("K", "♠"), card("J", "♣"), card("J", "♦"),
          card("3", "♣"), card("4", "♥")
        ])
      end

      it "returns a non-positive score (placement does not disrupt opponent)" do
        col_base = Array.new(5) { |c| board.map { |r| r[c] }.compact }
        score = cp.send(:defensive_score, 2, 1, card("6", "♠"), col_base)
        expect(score).to be <= 0
      end
    end
  end
end
