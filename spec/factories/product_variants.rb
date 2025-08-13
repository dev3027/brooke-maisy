FactoryBot.define do
  factory :product_variant do
    product { nil }
    name { "MyString" }
    sku { "MyString" }
    price { "9.99" }
    inventory_count { 1 }
    color { "MyString" }
    size { "MyString" }
    style { "MyString" }
    active { false }
  end
end
