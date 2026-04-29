# frozen_string_literal: true

require "rails_helper"

RSpec.describe Discovery::AtsFetcher, type: :service do
  let(:greenhouse_url) { "https://boards.greenhouse.io/acmecorp/jobs/12345" }
  let(:lever_url)      { "https://jobs.lever.co/acmecorp/abc-123-def" }
  let(:ashby_url)      { "https://jobs.ashbyhq.com/acmecorp/abc-123-def" }

  describe ".call" do
    context "when ats_type is 'greenhouse'" do
      it "delegates to GreenhouseFetcher" do
        expect(Discovery::GreenhouseFetcher).to receive(:call).with(greenhouse_url)
          .and_return({ success: true, response: { title: "Engineer" } })
        described_class.call(url: greenhouse_url, ats_type: "greenhouse")
      end

      it "returns the result from GreenhouseFetcher" do
        allow(Discovery::GreenhouseFetcher).to receive(:call)
          .and_return({ success: true, response: { title: "Engineer" } })
        result = described_class.call(url: greenhouse_url, ats_type: "greenhouse")
        expect(result[:success]).to be true
        expect(result[:response][:title]).to eq("Engineer")
      end
    end

    context "when ats_type is 'lever'" do
      it "delegates to LeverFetcher" do
        expect(Discovery::LeverFetcher).to receive(:call).with(lever_url)
          .and_return({ success: true, response: { title: "Engineer" } })
        described_class.call(url: lever_url, ats_type: "lever")
      end

      it "returns the result from LeverFetcher" do
        allow(Discovery::LeverFetcher).to receive(:call)
          .and_return({ success: true, response: { title: "Engineer" } })
        result = described_class.call(url: lever_url, ats_type: "lever")
        expect(result[:success]).to be true
      end
    end

    context "when ats_type is 'ashby'" do
      it "delegates to AshbyFetcher" do
        expect(Discovery::AshbyFetcher).to receive(:call).with(ashby_url)
          .and_return({ success: true, response: { title: "Engineer" } })
        described_class.call(url: ashby_url, ats_type: "ashby")
      end

      it "returns the result from AshbyFetcher" do
        allow(Discovery::AshbyFetcher).to receive(:call)
          .and_return({ success: true, response: { title: "Engineer" } })
        result = described_class.call(url: ashby_url, ats_type: "ashby")
        expect(result[:success]).to be true
      end
    end

    context "when ats_type is unsupported" do
      it "returns success: false" do
        result = described_class.call(url: "https://example.com/jobs/1", ats_type: "workday")
        expect(result[:success]).to be false
      end

      it "includes an error message naming the unsupported type" do
        result = described_class.call(url: "https://example.com/jobs/1", ats_type: "workday")
        expect(result[:response][:error][:message]).to include("Unsupported ATS type: workday")
      end

      it "does not raise" do
        expect {
          described_class.call(url: "https://example.com/jobs/1", ats_type: "jobvite")
        }.not_to raise_error
      end
    end

    context "when the adapter raises an unexpected error" do
      it "returns success: false with the error message" do
        allow(Discovery::GreenhouseFetcher).to receive(:call).and_raise(RuntimeError, "boom")
        result = described_class.call(url: greenhouse_url, ats_type: "greenhouse")
        expect(result[:success]).to be false
        expect(result[:response][:error][:message]).to eq("boom")
      end
    end
  end
end
