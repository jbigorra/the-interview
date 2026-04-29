require "rails_helper"

RSpec.describe Apply::GreenhouseAdapter, type: :service do
  let(:profile) do
    create(:profile,
      email:                 "dev@example.com",
      resume_text:           "10 years Ruby",
      cover_letter_template: "I love your mission.",
      personal_info:         { "first_name" => "Dev", "last_name" => "Smith", "phone" => "555-9999" },
      common_answers:        { "sponsorship" => "no" })
  end

  let(:url)  { "https://boards.greenhouse.io/acme/jobs/456" }
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

    it "returns fields as an array" do
      fields = adapter.extract_fields[:response][:fields]
      expect(fields).to be_an(Array)
    end

    it "includes the apply_url in the response" do
      expect(adapter.extract_fields[:response][:apply_url]).to eq(url)
    end

    it "pre-fills email from the profile" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "email" }
      expect(field[:value]).to eq("dev@example.com")
    end

    it "pre-fills first_name from personal_info" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "first_name" }
      expect(field[:value]).to eq("Dev")
    end

    it "pre-fills last_name from personal_info" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "last_name" }
      expect(field[:value]).to eq("Smith")
    end

    it "pre-fills resume from resume_text" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "resume" }
      expect(field[:value]).to eq("10 years Ruby")
    end

    it "pre-fills cover_letter from cover_letter_template" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "cover_letter" }
      expect(field[:value]).to eq("I love your mission.")
    end

    it "marks required fields as required" do
      fields = adapter.extract_fields[:response][:fields]
      required_ids = fields.select { |f| f[:required] }.map { |f| f[:id] }
      expect(required_ids).to include("first_name", "last_name", "email", "resume")
    end

    it "marks phone and cover_letter as not required" do
      fields = adapter.extract_fields[:response][:fields]
      optional_ids = fields.reject { |f| f[:required] }.map { |f| f[:id] }
      expect(optional_ids).to include("phone", "cover_letter")
    end
  end

  describe "#build_payload" do
    it "returns success: true" do
      expect(adapter.build_payload[:success]).to be true
    end

    it "includes the apply_url in the response" do
      expect(adapter.build_payload[:response][:apply_url]).to eq(url)
    end

    it "includes email in the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:email]).to eq("dev@example.com")
    end

    it "includes first_name in the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:first_name]).to eq("Dev")
    end

    it "includes last_name in the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:last_name]).to eq("Smith")
    end

    it "merges common answers into the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload["sponsorship"]).to eq("no")
    end

    it "common answers do not override standard symbol-keyed fields" do
      profile_with_collision = create(:profile,
        email:          "orig@example.com",
        common_answers: { "email" => "override@example.com" })
      lead_collision   = create(:lead, profile: profile_with_collision, url: url)
      adapter_collision = described_class.new(lead: lead_collision, profile: profile_with_collision)

      payload = adapter_collision.build_payload[:response][:payload]
      expect(payload[:email]).to eq("orig@example.com")
      expect(payload["email"]).to eq("override@example.com")
    end
  end
end
