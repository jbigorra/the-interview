require "rails_helper"

RSpec.describe Discovery::AtsDetector, type: :service do
  describe ".call" do
    context "when the URL matches a known ATS" do
      it "detects Lever" do
        result = described_class.call("https://jobs.lever.co/acme/abc-123")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("lever")
      end

      it "detects Greenhouse" do
        result = described_class.call("https://boards.greenhouse.io/acme/jobs/123")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("greenhouse")
      end

      it "detects Ashby" do
        result = described_class.call("https://jobs.ashbyhq.com/acme/abc")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("ashby")
      end

      it "detects Jobvite" do
        result = described_class.call("https://jobs.jobvite.com/acme/job/abc")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("jobvite")
      end

      it "detects Workday" do
        result = described_class.call("https://acme.myworkdayjobs.com/jobs/abc")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("workday")
      end

      it "detects JobScore" do
        result = described_class.call("https://careers.jobscore.com/careers/acme/jobs/abc")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("jobscore")
      end

      it "detects Comparably" do
        result = described_class.call("https://ats.comparably.com/acme/jobs/abc")
        expect(result[:success]).to be true
        expect(result[:response][:ats_type]).to eq("comparably")
      end

      it "echoes back the original URL in the response" do
        url = "https://jobs.lever.co/acme/abc-123"
        result = described_class.call(url)
        expect(result[:response][:url]).to eq(url)
      end
    end

    context "when the URL does not match any known ATS" do
      it "returns success: false with an error message" do
        result = described_class.call("https://careers.unknown-company.com/jobs/123")
        expect(result[:success]).to be false
        expect(result[:response][:error][:message]).to eq("Unknown ATS")
      end

      it "echoes back the original URL in the failure response" do
        url = "https://careers.unknown-company.com/jobs/123"
        result = described_class.call(url)
        expect(result[:response][:url]).to eq(url)
      end
    end

    context "when the URL is malformed" do
      it "returns success: false with an error message" do
        result = described_class.call("not a valid url ://")
        expect(result[:success]).to be false
        expect(result[:response][:error][:message]).to be_a(String)
      end
    end
  end
end
