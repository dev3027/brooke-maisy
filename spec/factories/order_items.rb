FactoryBot.define do
  factory :order_item do
    order { nil }
    product { nil }
    product_variant { nil }
    quantity { 1 }
    unit_price { "9.99" }
    total_price { "9.99" }
  end
end
