# frozen_string_literal: true

class CribbageHand
  RANK_ORDER = { "A" => 1, "2" => 2, "3" => 3, "4" => 4, "5" => 5,
                 "6" => 6, "7" => 7, "8" => 8, "9" => 9, "10" => 10,
                 "J" => 11, "Q" => 12, "K" => 13 }.freeze

  # cards:     array of { "rank" => str, "suit" => str, "id" => str } hashes
  # starter:   cut card (same format); used for nobs check and crib 5th card
  # is_center: true for row 2 / col 2 (enables nobs)
  # is_crib:   true for crib hand (starter added to @all_cards; strict flush rule)
  def initialize(cards, starter: nil, is_center: false, is_crib: false)
    @cards     = cards
    @starter   = starter
    @is_center = is_center
    @is_crib   = is_crib
    @all_cards = is_crib && starter ? cards + [starter] : cards
  end

  def score
    breakdown.values_at(:fifteens, :pairs, :runs, :flush, :nobs).sum
  end

  def breakdown
    {
      fifteens: fifteens,
      pairs:    pairs,
      runs:     runs,
      flush:    flush,
      nobs:     nobs,
      total:    fifteens + pairs + runs + flush + nobs
    }
  end

  private

  def fifteens
    total = 0
    (2..@all_cards.size).each do |n|
      @all_cards.combination(n).each do |combo|
        total += 2 if combo.sum { |c| fifteen_value(c) } == 15
      end
    end
    total
  end

  def pairs
    groups = @all_cards.group_by { |c| c["rank"] }.values
    groups.sum do |g|
      case g.size
      when 2 then 2
      when 3 then 6
      when 4 then 12
      else 0
      end
    end
  end

  def runs
    return 0 if @all_cards.size < 3

    values = @all_cards.map { |c| RANK_ORDER[c["rank"]] }.sort

    [5, 4, 3].each do |len|
      next if values.size < len
      total = values.combination(len).sum { |combo| consecutive?(combo) ? len : 0 }
      return total if total > 0
    end

    0
  end

  def flush
    return 0 if @all_cards.size < 4

    suits = @all_cards.map { |c| c["suit"] }

    if @is_crib
      return 0 if @all_cards.size < 5
      suits.uniq.size == 1 ? 5 : 0
    else
      suits.uniq.size == 1 ? suits.size : 0
    end
  end

  def nobs
    return 0 unless @is_center && @starter

    @all_cards.count do |c|
      c["rank"] == "J" &&
        c["suit"] == @starter["suit"] &&
        c["id"] != @starter["id"]
    end * 2
  end

  def consecutive?(values)
    values.sort.each_cons(2).all? { |a, b| b - a == 1 }
  end

  def fifteen_value(card)
    rank = card["rank"]
    return 10 if %w[10 J Q K].include?(rank)
    return 1  if rank == "A"
    rank.to_i
  end
end
