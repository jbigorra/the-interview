# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::ResultParser, type: :service do
  describe ".call" do
    let(:organic_results) do
      [
        {
          position: 1,
          title: "Acme Corp - Senior Software Engineer",
          link: "https://jobs.lever.co/acme/abc-123",
          snippet: "Acme Corp is hiring a Senior Software Engineer. Remote. Work from anywhere.",
          displayed_link: "https://jobs.lever.co/acme/abc-123"
        },
        {
          position: 2,
          title: "Beta Inc | Senior Software Engineer",
          link: "https://jobs.lever.co/beta/def-456",
          snippet: "Beta Inc is looking for a Senior Software Engineer to join our remote team.",
          displayed_link: "https://jobs.lever.co/beta/def-456"
        }
      ]
    end

    it "returns success: true" do
      result = described_class.call(organic_results)
      expect(result[:success]).to be true
    end

    it "returns a leads array in the response" do
      result = described_class.call(organic_results)
      expect(result[:response][:leads]).to be_an(Array)
    end

    it "parses one lead per organic result" do
      result = described_class.call(organic_results)
      expect(result[:response][:leads].size).to eq(2)
    end

    it "count matches leads array size" do
      result = described_class.call(organic_results)
      expect(result[:response][:count]).to eq(result[:response][:leads].size)
    end

    it "returns success: true with empty results" do
      result = described_class.call([])
      expect(result[:success]).to be true
      expect(result[:response][:leads]).to be_empty
      expect(result[:response][:count]).to eq(0)
    end

    it "filters out results with no URL" do
      results_with_nil_link = organic_results + [ { title: "No URL result", snippet: "nothing" } ]
      result = described_class.call(results_with_nil_link)
      expect(result[:response][:leads].size).to eq(2)
    end
  end

  describe ".parse_result" do
    context "with a 'Company - Title' pattern" do
      let(:result) do
        {
          title: "Acme Corp - Senior Software Engineer",
          link: "https://jobs.lever.co/acme/abc-123",
          snippet: "We are hiring a great engineer."
        }
      end

      it "extracts company from title prefix" do
        parsed = described_class.parse_result(result)
        expect(parsed[:company]).to eq("Acme Corp")
      end

      it "extracts job title from title suffix" do
        parsed = described_class.parse_result(result)
        expect(parsed[:title]).to eq("Senior Software Engineer")
      end

      it "sets url from :link key" do
        parsed = described_class.parse_result(result)
        expect(parsed[:url]).to eq("https://jobs.lever.co/acme/abc-123")
      end

      it "sets description from snippet" do
        parsed = described_class.parse_result(result)
        expect(parsed[:description]).to eq("We are hiring a great engineer.")
      end

      it "includes raw_payload" do
        parsed = described_class.parse_result(result)
        expect(parsed[:raw_payload]).to eq(result)
      end

      it "sets location to nil" do
        parsed = described_class.parse_result(result)
        expect(parsed[:location]).to be_nil
      end
    end

    context "with a 'Company | Title' pattern" do
      let(:result) do
        {
          title: "Beta Inc | Senior Software Engineer",
          link: "https://jobs.lever.co/beta/def-456",
          snippet: "Beta Inc seeks an engineer."
        }
      end

      it "extracts company from pipe-separated title" do
        parsed = described_class.parse_result(result)
        expect(parsed[:company]).to eq("Beta Inc")
      end

      it "extracts job title from pipe-separated title" do
        parsed = described_class.parse_result(result)
        expect(parsed[:title]).to eq("Senior Software Engineer")
      end
    end

    context "with a title that has no separator" do
      let(:result) do
        {
          title: "Senior Software Engineer at RemoteCo",
          link: "https://jobs.lever.co/remoteco/ghi-789",
          snippet: "Join RemoteCo."
        }
      end

      it "sets company to 'Unknown'" do
        parsed = described_class.parse_result(result)
        expect(parsed[:company]).to eq("Unknown")
      end

      it "uses the full title as job title" do
        parsed = described_class.parse_result(result)
        expect(parsed[:title]).to eq("Senior Software Engineer at RemoteCo")
      end
    end

    context "when :url key is present instead of :link" do
      let(:result) do
        {
          title: "Some Corp - Engineer",
          url: "https://boards.greenhouse.io/some-corp/jobs/1",
          snippet: "Some snippet."
        }
      end

      it "falls back to :url for the lead URL" do
        parsed = described_class.parse_result(result)
        expect(parsed[:url]).to eq("https://boards.greenhouse.io/some-corp/jobs/1")
      end
    end

    context "when result has no URL" do
      let(:result) { { title: "No link result", snippet: "Missing link." } }

      it "returns nil" do
        parsed = described_class.parse_result(result)
        expect(parsed).to be_nil
      end
    end

    context "when title and snippet are missing" do
      let(:result) { { link: "https://jobs.lever.co/x/y" } }

      it "handles nil title gracefully" do
        parsed = described_class.parse_result(result)
        expect(parsed).not_to be_nil
        expect(parsed[:title]).to be_a(String)
        expect(parsed[:company]).to eq("Unknown")
      end
    end
  end

  describe ".extract_company" do
    it "returns company from 'Company - Title' format" do
      expect(described_class.extract_company("Acme Corp - Engineer", "")).to eq("Acme Corp")
    end

    it "returns company from 'Company | Title' format" do
      expect(described_class.extract_company("Acme Corp | Engineer", "")).to eq("Acme Corp")
    end

    it "returns 'Unknown' when no separator present" do
      expect(described_class.extract_company("Plain Title", "")).to eq("Unknown")
    end
  end

  describe ".extract_job_title" do
    it "returns job title after dash separator" do
      expect(described_class.extract_job_title("Acme Corp - Senior Engineer")).to eq("Senior Engineer")
    end

    it "returns job title after pipe separator" do
      expect(described_class.extract_job_title("Acme Corp | Senior Engineer")).to eq("Senior Engineer")
    end

    it "returns full title when no separator" do
      expect(described_class.extract_job_title("Senior Engineer at Acme")).to eq("Senior Engineer at Acme")
    end
  end

  describe ".extract_location" do
    it "returns nil (heuristic phase — full extraction done at ATS page visit)" do
      expect(described_class.extract_location("Remote, US")).to be_nil
    end
  end
end
