FactoryBot.define do
  factory :event do
    sequence(:external_id) { |n| "ext_#{n}" }
    title { "Sample Event" }
    published_state { "published" }
    starts_at { Time.current + 2.days }

    organiser { { "name" => "Test Organiser" } }
    location { { "city" => "Indore" } }
    minimum_price { { "amount_in_cents" => 1000 } }
  end
end
