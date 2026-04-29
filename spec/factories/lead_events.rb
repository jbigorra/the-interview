FactoryBot.define do
  factory :lead_event do
    lead { nil }
    from_stage { "MyString" }
    to_stage { "MyString" }
    trigger { "MyString" }
  end
end
