FactoryBot.define do
  factory :review do
    product { nil }
    user { nil }
    rating { 1 }
    title { "MyString" }
    content { "MyText" }
    verified_purchase { false }
    helpful_count { 1 }
    approved { false }
  end
end
