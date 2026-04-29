FactoryBot.define do
  factory :note do
    association :lead
    body { "Great opportunity, matches my skills." }
    author { "user" }
  end
end
