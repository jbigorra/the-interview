require "rails_helper"

RSpec.describe Apply::GreenhouseAdapter, type: :service do
  let(:profile) do
    create(:profile,
      email:                "dev@example.com",
      resume_text:          "10 years Ruby",
      cover_letter_template: "I love your mission.",
      personal_info:        { "first_name" => "Dev", "last_name" => "Smith", "phone" => "555-9999" },
      common_answers:       { "sponsorship" => "no" })
  end

  let(:url) { "https://boards.greenhouse.io/acme/jobs/456" }
  let(:lead) { create(:lead, profile: profile, ats_type: "greenhouse", url: url) }

  subject(:adapter) { described_class.new(lead: lead, profile: profile) }

  describe "#apply_url" do
    it "returns the lead URL" do
      expect(adapter.apply_url).to eq(url)
    end
  end

  describe "#extract_fields" do
    it "returns success: true" do
      expect(adapter.extract_fields[:success]).to be true
    end

    it "includes standard fields in the response" do
      fields = adapter.extract_fields[:response][:fields]

      expect(fields[:email]).to eq("dev@example.com")
      expect(fields[:first_name]).to eq("Dev")
      expect(fields[:last_name]).to eq("Smith")
      expect(fields[:resume]).to eq("10 years Ruby")
      expect(fields[:cover_letter]).to eq("I love your mission.")
    end

    it "includes the apply_url in the response" do
      expect(adapter.extract_fields[:response][:apply_url]).to eq(url)
    end
  end

  describe "#build_payload" do
    it "returns success: true" do
      expect(adapter.build_payload[:success]).to be true
    end

    it "merges standard fields into the payload" do
      payload = adapter.build_payload[:response][:payload]

      expect(payload[:email]).to eq("dev@example.com")
      expect(payload[:resume]).to eq("10 years Ruby")
    end

    it "merges common answers into the payload" do
      payload = adapter.build_payload[:response][:payload]

      expect(payload["sponsorship"]).to eq("no")
    end

    it "common answers do not override standard fields" do
      profile_with_collision = create(:profile,
        email:        "orig@example.com",
        common_answers: { "email" => "override@example.com" })
      lead_collision = create(:lead, profile: profile_with_collision, url: url)
      adapter_collision = described_class.new(lead: lead_collision, profile: profile_with_collision)

      # standard_fields uses symbol keys; common_answers uses string keys — no collision
      payload = adapter_collision.build_payload[:response][:payload]
      expect(payload[:email]).to eq("orig@example.com")
      expect(payload["email"]).to eq("override@example.com")
    end
  end
end
