FactoryBot.define do
  factory :article do
    title { "MyString" }
    content { "MyText" }
    excerpt { "MyText" }
    slug { "MyString" }
    published { false }
    featured { false }
    author { nil }
    category { "MyString" }
    tags { "MyText" }
    meta_title { "MyString" }
    meta_description { "MyText" }
  end
end
