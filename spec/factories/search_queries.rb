FactoryBot.define do
  factory :search_query do
    profile { nil }
    title { "MyString" }
    portal { "MyString" }
    additional_filters { "MyString" }
    last_run_at { "2026-04-28 23:50:27" }
    run_count { 1 }
  end
end
