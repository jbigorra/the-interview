FactoryBot.define do
  factory :profile do
    full_name { "John Doe" }
    email { "john@example.com" }
    resume_text { "Experienced software engineer..." }
    cover_letter_template { "Dear Hiring Manager..." }
    common_answers { {} }
    personal_info { {} }
  end
end
