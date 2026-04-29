require "rails_helper"

RSpec.describe Apply::Orchestrator, type: :service do
  describe ".call" do
    let(:profile) { create(:profile) }

    context "when the lead has a supported ATS type" do
      it "routes to GreenhouseAdapter for greenhouse leads" do
        lead = create(:lead, profile: profile, ats_type: "greenhouse",
                      url: "https://boards.greenhouse.io/acme/jobs/123")
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:success]).to be true
        expect(result[:response][:adapter]).to be_a(Apply::GreenhouseAdapter)
      end

      it "routes to LeverAdapter for lever leads" do
        lead = create(:lead, profile: profile, ats_type: "lever",
                      url: "https://jobs.lever.co/acme/abc-123")
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:success]).to be true
        expect(result[:response][:adapter]).to be_a(Apply::LeverAdapter)
      end

      it "routes to AshbyAdapter for ashby leads" do
        lead = create(:lead, profile: profile, ats_type: "ashby",
                      url: "https://jobs.ashbyhq.com/acme/abc")
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:success]).to be true
        expect(result[:response][:adapter]).to be_a(Apply::AshbyAdapter)
      end

      it "includes the apply_url in the response" do
        url = "https://jobs.lever.co/acme/abc-123"
        lead = create(:lead, profile: profile, ats_type: "lever", url: url)
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:response][:apply_url]).to eq(url)
      end
    end

    context "when the lead has an unsupported ATS type" do
      it "returns success: false" do
        lead = create(:lead, profile: profile, ats_type: "workday",
                      url: "https://acme.myworkdayjobs.com/jobs/abc")
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:success]).to be false
      end

      it "includes an error message naming the unsupported ATS" do
        lead = create(:lead, profile: profile, ats_type: "workday",
                      url: "https://acme.myworkdayjobs.com/jobs/abc")
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:response][:error][:message]).to include("Unsupported ATS")
        expect(result[:response][:error][:message]).to include("workday")
      end

      it "includes the lead URL as apply_url fallback" do
        url = "https://acme.myworkdayjobs.com/jobs/abc"
        lead = create(:lead, profile: profile, ats_type: "workday", url: url)
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:response][:apply_url]).to eq(url)
      end
    end

    context "when the lead has a nil ats_type" do
      it "returns success: false" do
        lead = create(:lead, profile: profile, ats_type: nil,
                      url: "https://careers.unknown.com/jobs/123")
        result = described_class.call(lead: lead, profile: profile)

        expect(result[:success]).to be false
      end
    end
  end
end
