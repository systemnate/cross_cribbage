FactoryBot.define do
  factory :game do
    player1_token { SecureRandom.hex(16) }
    status        { "waiting" }
    board         { Array.new(5) { Array.new(5, nil) } }
    row_scores    { [nil, nil, nil, nil, nil] }
    col_scores    { [nil, nil, nil, nil, nil] }
    player1_deck  { [] }
    player2_deck  { [] }
    crib          { [] }
    starter_card  { nil }
    round         { 1 }
    crib_owner    { nil }
    current_turn  { nil }
    player1_crib_discards { 0 }
    player2_crib_discards { 0 }
    player1_peg   { 0 }
    player2_peg   { 0 }

    trait :active do
      status       { "active" }
      player2_token { SecureRandom.hex(16) }
      crib_owner   { "player1" }
      current_turn { "player2" }
    end
  end
end
