FactoryBot.define do
  factory :search_query do
    association :profile
    title { "Senior Software Engineer" }
    portal { "jobs.lever.co" }
    additional_filters { '-"remote in the US"' }
  end
end
