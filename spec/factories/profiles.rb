FactoryBot.define do
  factory :profile do
    full_name { "MyString" }
    email { "MyString" }
    resume_text { "MyText" }
    cover_letter_template { "MyText" }
    common_answers { "" }
    personal_info { "" }
  end
end
