# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::AshbyFetcher, type: :service do
  let(:company) { "acmecorp" }
  let(:job_id)  { "abc-123-def-456" }
  let(:url)     { "https://jobs.ashbyhq.com/#{company}/#{job_id}" }
  let(:api_url) { "https://api.ashbyhq.com/posting-api/job-board/#{company}" }

  let(:job_posting) do
    {
      "id"              => job_id,
      "title"           => "Senior Software Engineer",
      "locationName"    => "Remote",
      "descriptionPlain" => "We are looking for a Senior Software Engineer.",
      "organization"    => { "name" => "Acme Corp" }
    }
  end

  let(:api_response) do
    {
      "jobPostings" => [ job_posting ]
    }
  end

  describe ".call" do
    context "when the API returns a board with the requested job" do
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

      it "returns the company from organization.name" do
        result = described_class.call(url)
        expect(result[:response][:company]).to eq("Acme Corp")
      end

      it "returns the location from locationName" do
        result = described_class.call(url)
        expect(result[:response][:location]).to eq("Remote")
      end

      it "returns the description from descriptionPlain" do
        result = described_class.call(url)
        expect(result[:response][:description]).to include("Senior Software Engineer")
      end

      it "includes raw_payload" do
        result = described_class.call(url)
        expect(result[:response][:raw_payload]).to eq(job_posting)
      end
    end

    context "when the API nests postings under jobBoard key" do
      before do
        nested = { "jobBoard" => { "jobPostings" => [ job_posting ] } }
        stub_request(:get, api_url)
          .to_return(status: 200, body: nested.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "still finds the job posting" do
        result = described_class.call(url)
        expect(result[:success]).to be true
        expect(result[:response][:title]).to eq("Senior Software Engineer")
      end
    end

    context "when the job is not found in the board" do
      before do
        board = { "jobPostings" => [ job_posting.merge("id" => "different-id") ] }
        stub_request(:get, api_url)
          .to_return(status: 200, body: board.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns success: false" do
        result = described_class.call(url)
        expect(result[:success]).to be false
      end

      it "includes a job not found error message" do
        result = described_class.call(url)
        expect(result[:response][:error][:message]).to include("Job #{job_id} not found in Ashby board")
      end
    end

    context "when organization is missing — falls back to humanized company slug" do
      before do
        posting = job_posting.except("organization")
        board   = { "jobPostings" => [ posting ] }
        stub_request(:get, api_url)
          .to_return(status: 200, body: board.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "humanizes the company slug as fallback" do
        result = described_class.call(url)
        expect(result[:response][:company]).to eq("Acmecorp")
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
        expect(result[:response][:error][:message]).to include("Failed to parse Ashby API response")
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

      it "includes an Ashby API error message" do
        result = described_class.call(url)
        expect(result[:response][:error][:message]).to include("Ashby API error")
      end
    end
  end
end
