FactoryBot.define do
  factory :matching_criterion do
    association :profile
    required_keywords { ["Ruby", "Rails", "PostgreSQL"] }
    excluded_keywords { ["intern", "junior"] }
    min_salary { 120_000 }
    preferred_locations { ["US", "Remote"] }
    work_mode { "remote" }
    llm_threshold { 70 }
  end
end
