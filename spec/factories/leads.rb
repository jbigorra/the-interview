FactoryBot.define do
  factory :lead do
    association :profile
    title { "Senior Software Engineer" }
    company { "Acme Corp" }
    location { "Remote" }
    sequence(:url) { |n| "https://jobs.lever.co/acme/#{n}" }
    ats_type { "lever" }
    description { "We are looking for..." }
    stage { :fresh }
  end
end
