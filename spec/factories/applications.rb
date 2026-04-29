FactoryBot.define do
  factory :application do
    association :lead
    ats_type { "greenhouse" }
    status { "draft" }
    form_payload { {} }
    ats_response { {} }
  end
end
