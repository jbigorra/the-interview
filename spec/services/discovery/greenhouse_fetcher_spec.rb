# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::GreenhouseFetcher, type: :service do
  let(:company)  { "acmecorp" }
  let(:job_id)   { "12345" }
  let(:url)      { "https://boards.greenhouse.io/#{company}/jobs/#{job_id}" }
  let(:api_url)  { "https://boards-api.greenhouse.io/v1/boards/#{company}/jobs/#{job_id}" }

  let(:api_response) do
    {
      "id"          => 12345,
      "title"       => "Senior Software Engineer",
      "content"     => "<p>We are looking for a Senior Software Engineer.</p>",
      "departments" => [ { "id" => 1, "name" => "Engineering" } ],
      "locations"   => [ { "id" => 1, "name" => "Remote" } ],
      "location"    => { "name" => "Remote" }
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

      it "returns the job title" do
        result = described_class.call(url)
        expect(result[:response][:title]).to eq("Senior Software Engineer")
      end

      it "returns the company name from departments" do
        result = described_class.call(url)
        expect(result[:response][:company]).to eq("Engineering")
      end

      it "returns the location from locations array" do
        result = described_class.call(url)
        expect(result[:response][:location]).to eq("Remote")
      end

      it "returns the description from content field" do
        result = described_class.call(url)
        expect(result[:response][:description]).to include("Senior Software Engineer")
      end

      it "includes raw_payload" do
        result = described_class.call(url)
        expect(result[:response][:raw_payload]).to eq(api_response)
      end
    end

    context "when departments are missing — falls back to humanized company slug" do
      before do
        data = api_response.merge("departments" => [])
        stub_request(:get, api_url)
          .to_return(status: 200, body: data.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "humanizes the company slug as fallback" do
        result = described_class.call(url)
        expect(result[:response][:company]).to eq("Acmecorp")
      end
    end

    context "when locations are missing — falls back to location hash" do
      before do
        data = api_response.merge("locations" => [], "location" => { "name" => "New York" })
        stub_request(:get, api_url)
          .to_return(status: 200, body: data.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "uses the location hash name as fallback" do
        result = described_class.call(url)
        expect(result[:response][:location]).to eq("New York")
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
        expect(result[:response][:error][:message]).to include("Failed to parse Greenhouse API response")
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

      it "includes a Greenhouse API error message" do
        result = described_class.call(url)
        expect(result[:response][:error][:message]).to include("Greenhouse API error")
      end
    end
  end
end
