FactoryBot.define do
  factory :application do
    lead { nil }
    status { 1 }
    ats_type { "MyString" }
  end
end
