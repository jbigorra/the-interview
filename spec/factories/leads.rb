FactoryBot.define do
  factory :lead do
    profile { nil }
    title { "MyString" }
    company { "MyString" }
    location { "MyString" }
    url { "MyString" }
    ats_type { "MyString" }
    description { "MyText" }
    raw_payload { "MyText" }
    fingerprint { "MyString" }
    stage { 1 }
    match_score { 1 }
    match_recommendation { "MyString" }
    match_reasoning { "MyText" }
    evaluated_at { "2026-04-28 23:50:31" }
    stage_position { 1 }
  end
end
