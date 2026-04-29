require "rails_helper"

RSpec.describe Apply::AshbyAdapter, type: :service do
  let(:profile) do
    create(:profile,
      email:                 "dev@example.com",
      resume_text:           "10 years Ruby",
      cover_letter_template: "I love your mission.",
      personal_info:         { "first_name" => "Dev", "last_name" => "Smith", "phone" => "555-9999" },
      common_answers:        { "sponsorship" => "no" })
  end

  let(:url)  { "https://jobs.ashbyhq.com/acme/abc" }
  let(:lead) { create(:lead, profile: profile, ats_type: "ashby", url: url) }

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

    it "pre-fills firstName from personal_info" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "firstName" }
      expect(field[:value]).to eq("Dev")
    end

    it "pre-fills lastName from personal_info" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "lastName" }
      expect(field[:value]).to eq("Smith")
    end

    it "pre-fills email from the profile" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "email" }
      expect(field[:value]).to eq("dev@example.com")
    end

    it "pre-fills coverLetter from cover_letter_template" do
      field = adapter.extract_fields[:response][:fields].find { |f| f[:id] == "coverLetter" }
      expect(field[:value]).to eq("I love your mission.")
    end

    it "marks firstName, lastName, email, and resume as required" do
      fields = adapter.extract_fields[:response][:fields]
      required_ids = fields.select { |f| f[:required] }.map { |f| f[:id] }
      expect(required_ids).to include("firstName", "lastName", "email", "resume")
    end

    it "marks phone and coverLetter as not required" do
      fields = adapter.extract_fields[:response][:fields]
      optional_ids = fields.reject { |f| f[:required] }.map { |f| f[:id] }
      expect(optional_ids).to include("phone", "coverLetter")
    end
  end

  describe "#build_payload" do
    it "returns success: true" do
      expect(adapter.build_payload[:success]).to be true
    end

    it "includes the apply_url in the response" do
      expect(adapter.build_payload[:response][:apply_url]).to eq(url)
    end

    it "uses camelCase firstName key" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:firstName]).to eq("Dev")
    end

    it "uses camelCase lastName key" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:lastName]).to eq("Smith")
    end

    it "uses camelCase coverLetter key" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:coverLetter]).to eq("I love your mission.")
    end

    it "includes email in the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload[:email]).to eq("dev@example.com")
    end

    it "merges common answers into the payload" do
      payload = adapter.build_payload[:response][:payload]
      expect(payload["sponsorship"]).to eq("no")
    end
  end
end
