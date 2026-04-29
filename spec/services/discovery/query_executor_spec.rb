# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::QueryExecutor, type: :service do
  let(:profile) { create(:profile) }
  let(:search_query) do
    create(:search_query,
      profile: profile,
      title: "Senior Software Engineer",
      portal: "jobs.lever.co",
      additional_filters: '-"remote in the US"',
      run_count: 0,
      last_run_at: nil)
  end

  let(:serpapi_organic_results) do
    [
      {
        position: 1,
        title: "Acme Corp - Senior Software Engineer",
        link: "https://jobs.lever.co/acme/abc-123",
        snippet: "Acme Corp is hiring. Remote. Work from anywhere."
      },
      {
        position: 2,
        title: "Beta Inc | Senior Software Engineer",
        link: "https://jobs.lever.co/beta/def-456",
        snippet: "Beta Inc is looking for an engineer."
      }
    ]
  end

  describe ".build_query" do
    it "builds a Google dork query with site, title, remote, and filters" do
      query = described_class.build_query(search_query)
      expect(query).to eq('site:jobs.lever.co "Senior Software Engineer" "remote" -"remote in the US"')
    end

    it "omits additional_filters when nil" do
      search_query.additional_filters = nil
      query = described_class.build_query(search_query)
      expect(query).to eq('site:jobs.lever.co "Senior Software Engineer" "remote"')
    end

    it "omits additional_filters when empty string" do
      search_query.additional_filters = ""
      query = described_class.build_query(search_query)
      expect(query).to eq('site:jobs.lever.co "Senior Software Engineer" "remote"')
    end

    it "always includes the 'remote' keyword" do
      query = described_class.build_query(search_query)
      expect(query).to include('"remote"')
    end

    it "wraps title in double quotes" do
      query = described_class.build_query(search_query)
      expect(query).to include('"Senior Software Engineer"')
    end

    it "prefixes portal with site: directive" do
      query = described_class.build_query(search_query)
      expect(query).to start_with("site:jobs.lever.co")
    end
  end

  describe ".call" do
    context "when SerpApi returns organic results" do
      before do
        allow(described_class).to receive(:execute_serpapi).and_return(serpapi_organic_results)
      end

      it "returns success: true" do
        result = described_class.call(search_query)
        expect(result[:success]).to be true
      end

      it "includes results array in response" do
        result = described_class.call(search_query)
        expect(result[:response][:results]).to be_an(Array)
        expect(result[:response][:results].size).to eq(2)
      end

      it "includes query string in response" do
        result = described_class.call(search_query)
        expect(result[:response][:query]).to include("site:jobs.lever.co")
      end

      it "includes count matching results size" do
        result = described_class.call(search_query)
        expect(result[:response][:count]).to eq(2)
      end

      it "updates last_run_at on the search_query" do
        expect { described_class.call(search_query) }
          .to change { search_query.reload.last_run_at }.from(nil)
      end

      it "increments run_count on the search_query" do
        expect { described_class.call(search_query) }
          .to change { search_query.reload.run_count }.from(0).to(1)
      end
    end

    context "when SerpApi returns empty organic results" do
      before do
        allow(described_class).to receive(:execute_serpapi).and_return([])
      end

      it "returns success: true with empty results" do
        result = described_class.call(search_query)
        expect(result[:success]).to be true
        expect(result[:response][:results]).to be_empty
        expect(result[:response][:count]).to eq(0)
      end
    end

    context "when SerpApi raises a SerpApiError" do
      before do
        allow(described_class).to receive(:execute_serpapi)
          .and_raise(SerpApi::SerpApiError, "Invalid API key")
      end

      it "returns success: false" do
        result = described_class.call(search_query)
        expect(result[:success]).to be false
      end

      it "includes error message with SerpApi prefix" do
        result = described_class.call(search_query)
        expect(result[:response][:error][:message]).to include("SerpApi error: Invalid API key")
      end

      it "includes the query in error response" do
        result = described_class.call(search_query)
        expect(result[:response][:query]).to include("site:jobs.lever.co")
      end

      it "does not update run_count on failure" do
        expect { described_class.call(search_query) }
          .not_to change { search_query.reload.run_count }
      end
    end

    context "when an unexpected error occurs" do
      before do
        allow(described_class).to receive(:execute_serpapi)
          .and_raise(RuntimeError, "Network timeout")
      end

      it "returns success: false" do
        result = described_class.call(search_query)
        expect(result[:success]).to be false
      end

      it "includes error message in response" do
        result = described_class.call(search_query)
        expect(result[:response][:error][:message]).to eq("Network timeout")
      end
    end
  end

  describe ".execute_serpapi" do
    let(:serpapi_response) do
      {
        search_metadata: { id: "abc123", status: "Success" },
        organic_results: [
          { position: 1, title: "Acme Corp - Senior Software Engineer", link: "https://jobs.lever.co/acme/abc-123" }
        ]
      }
    end

    before do
      stub_request(:get, "https://serpapi.com/search")
        .with(query: hash_including({ "engine" => "google", "q" => 'site:jobs.lever.co "Senior Software Engineer" "remote"' }))
        .to_return(status: 200, body: serpapi_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "calls SerpApi and returns the organic_results array" do
      allow(ENV).to receive(:fetch).with("SERPAPI_API_KEY", nil).and_return("test-api-key")
      results = described_class.send(:execute_serpapi, 'site:jobs.lever.co "Senior Software Engineer" "remote"')
      expect(results).to be_an(Array)
      expect(results.first[:title]).to include("Senior Software Engineer")
    end

    it "returns empty array when no organic_results key present" do
      stub_request(:get, "https://serpapi.com/search")
        .with(query: hash_including({ "engine" => "google", "q" => "site:jobs.lever.co" }))
        .to_return(status: 200, body: { search_metadata: { status: "Success" } }.to_json,
          headers: { "Content-Type" => "application/json" })
      allow(ENV).to receive(:fetch).with("SERPAPI_API_KEY", nil).and_return("test-api-key")
      results = described_class.send(:execute_serpapi, "site:jobs.lever.co")
      expect(results).to eq([])
    end
  end
end
