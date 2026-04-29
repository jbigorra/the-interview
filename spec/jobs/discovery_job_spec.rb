# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoveryJob, type: :job do
  let(:profile) { create(:profile) }
  let(:search_query) { create(:search_query, profile: profile, last_run_at: nil) }

  let(:serpapi_results) do
    [
      {
        title: "Acme Corp - Senior Software Engineer",
        link: "https://jobs.lever.co/acme/abc-123",
        snippet: "Great remote role"
      }
    ]
  end

  let(:parsed_leads) do
    [
      {
        title: "Senior Software Engineer",
        company: "Acme Corp",
        location: nil,
        url: "https://jobs.lever.co/acme/abc-123",
        description: "Great remote role",
        raw_payload: { title: "Acme Corp - Senior Software Engineer" }
      }
    ]
  end

  before do
    allow(Discovery::QueryExecutor).to receive(:call).and_return(
      { success: true, response: { results: serpapi_results, query: "site:jobs.lever.co", count: 1 } }
    )
    allow(Discovery::ResultParser).to receive(:call).and_return(
      { success: true, response: { leads: parsed_leads, count: 1 } }
    )
    allow(Discovery::AtsDetector).to receive(:call).and_return(
      { success: true, response: { ats_type: "lever", url: "https://jobs.lever.co/acme/abc-123" } }
    )
  end

  describe "#perform" do
    context "when query was recently run" do
      before { search_query.update!(last_run_at: 1.hour.ago) }

      it "does not call QueryExecutor" do
        described_class.new.perform(search_query)
        expect(Discovery::QueryExecutor).not_to have_received(:call)
      end

      it "does not create any leads" do
        expect { described_class.new.perform(search_query) }
          .not_to change(Lead, :count)
      end
    end

    context "when QueryExecutor fails" do
      before do
        allow(Discovery::QueryExecutor).to receive(:call).and_return(
          { success: false, response: { error: { message: "API error" } } }
        )
      end

      it "does not call ResultParser" do
        described_class.new.perform(search_query)
        expect(Discovery::ResultParser).not_to have_received(:call)
      end

      it "does not create any leads" do
        expect { described_class.new.perform(search_query) }
          .not_to change(Lead, :count)
      end
    end

    context "when ResultParser fails" do
      before do
        allow(Discovery::ResultParser).to receive(:call).and_return(
          { success: false, response: { error: { message: "parse error" } } }
        )
      end

      it "does not create any leads" do
        expect { described_class.new.perform(search_query) }
          .not_to change(Lead, :count)
      end
    end

    context "when all services succeed" do
      it "creates a lead for each parsed result" do
        expect { described_class.new.perform(search_query) }
          .to change(Lead, :count).by(1)
      end

      it "sets the lead URL from parsed data" do
        described_class.new.perform(search_query)
        lead = Lead.last
        expect(lead.url).to eq("https://jobs.lever.co/acme/abc-123")
      end

      it "sets ats_type from AtsDetector result" do
        described_class.new.perform(search_query)
        expect(Lead.last.ats_type).to eq("lever")
      end

      it "sets stage to :fresh" do
        described_class.new.perform(search_query)
        expect(Lead.last.stage).to eq("fresh")
      end

      it "assigns the lead to the correct profile" do
        described_class.new.perform(search_query)
        expect(Lead.last.profile).to eq(profile)
      end

      it "enqueues Stage1MatchingJob for the new lead" do
        expect { described_class.new.perform(search_query) }
          .to have_enqueued_job(Stage1MatchingJob)
      end

      context "when AtsDetector fails (unknown ATS)" do
        before do
          allow(Discovery::AtsDetector).to receive(:call).and_return(
            { success: false, response: { error: { message: "Unknown ATS" }, url: "https://jobs.lever.co/acme/abc-123" } }
          )
        end

        it "sets ats_type to 'unknown'" do
          described_class.new.perform(search_query)
          expect(Lead.last.ats_type).to eq("unknown")
        end

        it "still creates the lead" do
          expect { described_class.new.perform(search_query) }
            .to change(Lead, :count).by(1)
        end
      end
    end

    context "deduplication" do
      it "skips leads whose URL fingerprint already exists for the profile" do
        fingerprint = Digest::SHA256.hexdigest("https://jobs.lever.co/acme/abc-123")
        create(:lead, profile: profile, url: "https://jobs.lever.co/acme/abc-123", fingerprint: fingerprint)

        expect { described_class.new.perform(search_query) }
          .not_to change(Lead, :count)
      end

      it "does not enqueue Stage1MatchingJob for duplicate leads" do
        fingerprint = Digest::SHA256.hexdigest("https://jobs.lever.co/acme/abc-123")
        create(:lead, profile: profile, url: "https://jobs.lever.co/acme/abc-123", fingerprint: fingerprint)

        expect { described_class.new.perform(search_query) }
          .not_to have_enqueued_job(Stage1MatchingJob)
      end

      it "creates leads for URLs not yet seen, skips existing ones" do
        fingerprint = Digest::SHA256.hexdigest("https://jobs.lever.co/acme/abc-123")
        create(:lead, profile: profile, url: "https://jobs.lever.co/acme/abc-123", fingerprint: fingerprint)

        new_lead_data = {
          title: "Backend Engineer",
          company: "Beta Corp",
          location: nil,
          url: "https://jobs.lever.co/beta/xyz-999",
          description: "Another role",
          raw_payload: {}
        }
        allow(Discovery::ResultParser).to receive(:call).and_return(
          { success: true, response: { leads: [ parsed_leads.first, new_lead_data ], count: 2 } }
        )
        allow(Discovery::AtsDetector).to receive(:call).with("https://jobs.lever.co/beta/xyz-999").and_return(
          { success: true, response: { ats_type: "lever", url: "https://jobs.lever.co/beta/xyz-999" } }
        )

        expect { described_class.new.perform(search_query) }
          .to change(Lead, :count).by(1)
      end
    end
  end
end
