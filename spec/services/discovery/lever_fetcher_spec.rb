# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::LeverFetcher, type: :service do
  let(:company) { "acmecorp" }
  let(:job_id)  { "abc-123-def-456" }
  let(:url)     { "https://jobs.lever.co/#{company}/#{job_id}" }
  let(:api_url) { "https://api.lever.co/v0/postings/#{company}/#{job_id}" }

  let(:api_response) do
    {
      "id"               => job_id,
      "text"             => "Senior Software Engineer",
      "descriptionPlain" => "We are looking for a Senior Software Engineer.",
      "categories"       => {
        "team"     => "Engineering",
        "location" => "Remote"
      },
      "workplaceType"    => "remote"
    }
  end

  describe ".call" do
    context "when the API returns a valid job" do
      before do
        stub_request(:get, api_url)
          .to_return(status: 200, body: api_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns success: true" do
        result = described_class.call(url)
        expect(result[:success]).to be true
      end

      it "returns the job title from the text field" do
        result = described_class.call(url)
        expect(result[:response][:title]).to eq("Senior Software Engineer")
      end

      it "returns the company from categories.team" do
        result = described_class.call(url)
        expect(result[:response][:company]).to eq("Engineering")
      end

      it "returns the location from categories.location" do
        result = described_class.call(url)
        expect(result[:response][:location]).to eq("Remote")
      end

      it "returns the description from descriptionPlain" do
        result = described_class.call(url)
        expect(result[:response][:description]).to include("Senior Software Engineer")
      end

      it "includes raw_payload" do
        result = described_class.call(url)
        expect(result[:response][:raw_payload]).to eq(api_response)
      end
    end

    context "when categories are missing — falls back to humanized company slug" do
      before do
        data = api_response.merge("categories" => {})
        stub_request(:get, api_url)
          .to_return(status: 200, body: data.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "humanizes the company slug as fallback" do
        result = described_class.call(url)
        expect(result[:response][:company]).to eq("Acmecorp")
      end
    end

    context "when categories.location is missing — falls back to workplaceType" do
      before do
        data = api_response.merge("categories" => { "team" => "Engineering" })
        stub_request(:get, api_url)
          .to_return(status: 200, body: data.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "uses workplaceType as location fallback" do
        result = described_class.call(url)
        expect(result[:response][:location]).to eq("remote")
      end
    end

    context "when the API returns invalid JSON" do
      before do
        stub_request(:get, api_url)
          .to_return(status: 200, body: "not json", headers: { "Content-Type" => "text/html" })
      end

      it "returns success: false" do
        result = described_class.call(url)
        expect(result[:success]).to be false
      end

      it "includes a parse error message" do
        result = described_class.call(url)
        expect(result[:response][:error][:message]).to include("Failed to parse Lever API response")
      end
    end

    context "when a network error occurs" do
      before do
        stub_request(:get, api_url).to_raise(SocketError.new("Failed to open TCP connection"))
      end

      it "returns success: false" do
        result = described_class.call(url)
        expect(result[:success]).to be false
      end

      it "includes a Lever API error message" do
        result = described_class.call(url)
        expect(result[:response][:error][:message]).to include("Lever API error")
      end
    end
  end
end
