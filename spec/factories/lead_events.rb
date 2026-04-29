FactoryBot.define do
  factory :lead_event do
    association :lead
    from_stage { 0 }
    to_stage { 1 }
    trigger { "manual" }
  end
end
