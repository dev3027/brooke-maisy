FactoryBot.define do
  factory :order do
    user { nil }
    order_number { "MyString" }
    status { "MyString" }
    total_amount { "9.99" }
    shipping_address { "MyText" }
    billing_address { "MyText" }
    payment_status { "MyString" }
    payment_method { "MyString" }
    stripe_payment_intent_id { "MyString" }
    notes { "MyText" }
  end
end
