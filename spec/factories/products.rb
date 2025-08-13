FactoryBot.define do
  factory :product do
    name { "MyString" }
    description { "MyText" }
    price { "9.99" }
    sku { "MyString" }
    category { nil }
    active { false }
    featured { false }
    inventory_count { 1 }
    weight { "9.99" }
    dimensions { "MyString" }
    materials { "MyText" }
    care_instructions { "MyText" }
    slug { "MyString" }
  end
end
