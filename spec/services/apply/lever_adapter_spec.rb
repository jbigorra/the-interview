require "rails_helper"

RSpec.describe Apply::LeverAdapter, type: :service do
  let(:profile) do
    create(:profile,
      email:                 "dev@example.com",
      resume_text:           "10 years Ruby",
      cover_letter_template: "I love your mission.",
      personal_info:         { "first_name" => "Dev", "last_name" => "Smith", "phone" => "555-9999" },
      common_answers:        { "sponsorship" => "no" })
  end

  let(:url)  { "https://jobs.lever.co/acme/abc-123" }
  let(:lead) { create(:lead, profile: profile, ats_type: "lever", url: url) }

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

    it "pre-fills the name field by joining first and last name" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "name" }
      expect(field[:value]).to eq("Dev Smith")
    end

    it "pre-fills email from the profile" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "email" }
      expect(field[:value]).to eq("dev@example.com")
    end

    it "pre-fills cover from cover_letter_template" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "cover" }
      expect(field[:value]).to eq("I love your mission.")
    end

    it "marks name and email and resume as required" do
      fields = adapter.extract_fields[:response][:fields]
      required_ids = fields.select { |f| f[:required] }.map { |f| f[:id] }
      expect(required_ids).to include("name", "email", "resume")
    end

    it "returns an empty string for name when personal_info is blank" do
      profile_no_name = create(:profile, personal_info: {})
      lead_no_name    = create(:lead, profile: profile_no_name, url: url)
      adapter_no_name = described_class.new(lead: lead_no_name, profile: profile_no_name)

      field = adapter_no_name.extract_fields[:response][:fields].find { |f| f[:id] == "name" }
      expect(field[:value]).to eq("")
    end
  end

  describe "#build_payload" do
    it "returns success: true" do
      expect(adapter.build_payload[:success]).to be true
    end

    it "includes the apply_url in the response" do
      expect(adapter.build_payload[:response][:apply_url]).to eq(url)
    end

    it "sets name to the full combined name" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:name]).to eq("Dev Smith")
    end

    it "includes email in the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:email]).to eq("dev@example.com")
    end

    it "merges common answers into the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload["sponsorship"]).to eq("no")
    end

    it "omits name from payload when personal_info is blank" do
      profile_no_name = create(:profile, personal_info: {})
      lead_no_name    = create(:lead, profile: profile_no_name, url: url)
      adapter_no_name = described_class.new(lead: lead_no_name, profile: profile_no_name)

      payload = adapter_no_name.build_payload[:response][:payload]
      expect(payload).not_to have_key(:name)
    end
  end
end
