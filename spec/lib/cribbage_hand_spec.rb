# spec/lib/cribbage_hand_spec.rb
require "rails_helper"

RSpec.describe CribbageHand do
  def card(rank, suit)
    { "rank" => rank, "suit" => suit, "id" => SecureRandom.uuid }
  end

  describe "#score" do
    context "fifteens" do
      it "scores 2 for a single fifteen (5 + 10)" do
        hand = described_class.new([card("5", "♠"), card("10", "♥")])
        expect(hand.score).to eq(2)
      end

      it "scores 4 for two fifteens (7 + 8, 5 + 10)" do
        hand = described_class.new([card("7", "♠"), card("8", "♥"), card("5", "♦"), card("10", "♣")])
        expect(hand.score).to eq(4)
      end

      it "scores 8 for four fifteens (5 5 5 with a face card)" do
        # 5+K(10)=15 × 3 combos = 6 pts, plus 5+5+5=15 × 1 combo = 2 pts → 8 pts total for fifteens
        hand = described_class.new([card("5", "♠"), card("5", "♥"), card("5", "♦"), card("K", "♣")])
        expect(hand.breakdown[:fifteens]).to eq(8)
      end

      it "counts A as 1 for fifteens" do
        hand = described_class.new([card("A", "♠"), card("4", "♥"), card("10", "♦")])
        expect(hand.score).to eq(2)
      end

      it "scores 0 when no combination sums to 15" do
        hand = described_class.new([card("2", "♠"), card("3", "♥")])
        expect(hand.breakdown[:fifteens]).to eq(0)
      end
    end

    context "pairs" do
      it "scores 2 for a pair" do
        hand = described_class.new([card("K", "♠"), card("K", "♥")])
        expect(hand.breakdown[:pairs]).to eq(2)
      end

      it "scores 6 for three of a kind" do
        hand = described_class.new([card("7", "♠"), card("7", "♥"), card("7", "♦")])
        expect(hand.breakdown[:pairs]).to eq(6)
      end

      it "scores 12 for four of a kind" do
        hand = described_class.new([card("4", "♠"), card("4", "♥"), card("4", "♦"), card("4", "♣")])
        expect(hand.breakdown[:pairs]).to eq(12)
      end

      it "scores 0 when no pairs" do
        hand = described_class.new([card("A", "♠"), card("2", "♥"), card("3", "♦")])
        expect(hand.breakdown[:pairs]).to eq(0)
      end
    end

    context "runs" do
      it "scores 3 for a run of 3" do
        hand = described_class.new([card("7", "♠"), card("8", "♥"), card("9", "♦")])
        expect(hand.breakdown[:runs]).to eq(3)
      end

      it "scores 4 for a run of 4" do
        hand = described_class.new([card("6", "♠"), card("7", "♥"), card("8", "♦"), card("9", "♣")])
        expect(hand.breakdown[:runs]).to eq(4)
      end

      it "scores 5 for a run of 5" do
        hand = described_class.new([card("5", "♠"), card("6", "♥"), card("7", "♦"), card("8", "♣"), card("9", "♠")])
        expect(hand.breakdown[:runs]).to eq(5)
      end

      it "scores 6 for a double run of 3 (pair + run)" do
        # K Q J J → two runs of 3: K-Q-J(first), K-Q-J(second)
        hand = described_class.new([card("K", "♠"), card("Q", "♥"), card("J", "♦"), card("J", "♣")])
        expect(hand.breakdown[:runs]).to eq(6)
      end

      it "scores 8 for a double run of 4 (pair + run of 4)" do
        hand = described_class.new([
          card("10", "♠"), card("J", "♥"), card("Q", "♦"), card("K", "♣"), card("K", "♠")
        ])
        expect(hand.breakdown[:runs]).to eq(8)
      end

      it "scores 0 for no run" do
        hand = described_class.new([card("A", "♠"), card("3", "♥"), card("7", "♦")])
        expect(hand.breakdown[:runs]).to eq(0)
      end
    end

    context "flush" do
      it "scores 4 for four cards of the same suit" do
        cards = [card("2", "♠"), card("5", "♠"), card("8", "♠"), card("K", "♠")]
        hand = described_class.new(cards)
        expect(hand.breakdown[:flush]).to eq(4)
      end

      it "scores 5 for five cards of the same suit" do
        cards = [card("2", "♠"), card("5", "♠"), card("7", "♠"), card("9", "♠"), card("K", "♠")]
        hand = described_class.new(cards)
        expect(hand.breakdown[:flush]).to eq(5)
      end

      it "scores 0 for three cards of the same suit" do
        cards = [card("2", "♠"), card("5", "♠"), card("8", "♠")]
        hand = described_class.new(cards)
        expect(hand.breakdown[:flush]).to eq(0)
      end

      it "scores 0 when suits differ" do
        cards = [card("2", "♠"), card("5", "♠"), card("8", "♠"), card("K", "♥")]
        hand = described_class.new(cards)
        expect(hand.breakdown[:flush]).to eq(0)
      end

      context "crib (is_crib: true)" do
        it "scores 5 only when all 5 cards (including starter) are same suit" do
          starter = card("3", "♠")
          hand = described_class.new(
            [card("2", "♠"), card("5", "♠"), card("7", "♠"), card("9", "♠")],
            starter: starter, is_crib: true
          )
          expect(hand.breakdown[:flush]).to eq(5)
        end

        it "scores 0 when only 4 of 5 crib cards match suit" do
          starter = card("3", "♥")
          hand = described_class.new(
            [card("2", "♠"), card("5", "♠"), card("7", "♠"), card("9", "♠")],
            starter: starter, is_crib: true
          )
          expect(hand.breakdown[:flush]).to eq(0)
        end
      end
    end

    context "nobs" do
      let(:starter) { card("Q", "♥") }

      it "scores 2 for a Jack matching starter suit in center hand" do
        hand = described_class.new(
          [card("J", "♥"), card("2", "♠")],
          starter: starter, is_center: true
        )
        expect(hand.breakdown[:nobs]).to eq(2)
      end

      it "scores 0 for a Jack not matching starter suit" do
        hand = described_class.new(
          [card("J", "♠"), card("2", "♥")],
          starter: starter, is_center: true
        )
        expect(hand.breakdown[:nobs]).to eq(0)
      end

      it "scores 0 when is_center is false" do
        hand = described_class.new(
          [card("J", "♥"), card("2", "♠")],
          starter: starter, is_center: false
        )
        expect(hand.breakdown[:nobs]).to eq(0)
      end

      it "does not count the starter itself for nobs (starter is a Jack)" do
        jack_starter = card("J", "♥")
        hand = described_class.new(
          [jack_starter, card("2", "♠")],
          starter: jack_starter, is_center: true
        )
        # The Jack IS the starter, so nobs = 0 (it already scored nibs separately)
        expect(hand.breakdown[:nobs]).to eq(0)
      end
    end

    context "partial hands (< 5 cards)" do
      it "scores a partial 15 with 2 cards (7 + 8)" do
        hand = described_class.new([card("7", "♠"), card("8", "♥")])
        expect(hand.score).to eq(2)
      end

      it "scores a pair with 2 cards" do
        hand = described_class.new([card("K", "♠"), card("K", "♥")])
        expect(hand.score).to eq(2)
      end

      it "returns 0 for a single card with no combinations" do
        hand = described_class.new([card("8", "♠")])
        expect(hand.score).to eq(0)
      end

      it "returns 0 for two cards with no combinations" do
        hand = described_class.new([card("2", "♠"), card("9", "♥")])
        expect(hand.score).to eq(0)
      end
    end

    context "breakdown" do
      it "returns a hash with all scoring components" do
        hand = described_class.new([card("5", "♠"), card("10", "♥"), card("K", "♦")])
        bd = hand.breakdown
        expect(bd).to include(:fifteens, :pairs, :runs, :flush, :nobs, :total)
        expect(bd[:total]).to eq(hand.score)
      end
    end

    context "crib scoring" do
      it "scores 4 crib cards + starter as a 5-card hand" do
        starter = card("5", "♠")
        # A 2 3 4 + starter 5 → run of 5 = 5 pts
        hand = described_class.new(
          [card("A", "♠"), card("2", "♥"), card("3", "♦"), card("4", "♣")],
          starter: starter, is_crib: true
        )
        expect(hand.breakdown[:runs]).to eq(5)
      end
    end
  end
end
