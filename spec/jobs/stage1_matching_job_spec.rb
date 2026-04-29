# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stage1MatchingJob, type: :job do
  let(:profile) { create(:profile) }
  let(:lead) { create(:lead, profile: profile, stage: :fresh, description: "Rails Ruby PostgreSQL remote role") }

  describe "#perform" do
    describe "ATS enrichment" do
      let(:ats_response) do
        {
          success: true,
          response: {
            title:       "Backend Engineer",
            company:     "Enriched Corp",
            location:    "Remote",
            description: "A" * 300,
            raw_payload: { "id" => "abc" }
          }
        }
      end

      context "when the lead description is blank" do
        let(:lead) { create(:lead, profile: profile, stage: :fresh, ats_type: "greenhouse", description: nil) }

        it "calls AtsFetcher before evaluation" do
          expect(Discovery::AtsFetcher).to receive(:call)
            .with(url: lead.url, ats_type: "greenhouse")
            .and_return(ats_response)
          described_class.new.perform(lead)
        end

        it "updates the lead description from ATS data" do
          allow(Discovery::AtsFetcher).to receive(:call).and_return(ats_response)
          described_class.new.perform(lead)
          expect(lead.reload.description).to eq("A" * 300)
        end

        it "fills in blank title from ATS data" do
          lead.update!(title: nil)
          allow(Discovery::AtsFetcher).to receive(:call).and_return(ats_response)
          described_class.new.perform(lead)
          expect(lead.reload.title).to eq("Backend Engineer")
        end

        it "does not overwrite an existing title" do
          lead.update!(title: "Existing Title")
          allow(Discovery::AtsFetcher).to receive(:call).and_return(ats_response)
          described_class.new.perform(lead)
          expect(lead.reload.title).to eq("Existing Title")
        end
      end

      context "when the lead description is present but shorter than 200 chars" do
        let(:lead) { create(:lead, profile: profile, stage: :fresh, ats_type: "lever", description: "Short snippet") }

        it "calls AtsFetcher" do
          expect(Discovery::AtsFetcher).to receive(:call)
            .with(url: lead.url, ats_type: "lever")
            .and_return(ats_response)
          described_class.new.perform(lead)
        end

        it "updates the description with the full ATS content" do
          allow(Discovery::AtsFetcher).to receive(:call).and_return(ats_response)
          described_class.new.perform(lead)
          expect(lead.reload.description).to eq("A" * 300)
        end
      end

      context "when the lead description is 200 chars or longer" do
        let(:lead) { create(:lead, profile: profile, stage: :fresh, ats_type: "greenhouse", description: "B" * 200) }

        it "does not call AtsFetcher" do
          expect(Discovery::AtsFetcher).not_to receive(:call)
          described_class.new.perform(lead)
        end
      end

      context "when the lead ats_type is not a known provider" do
        let(:lead) { create(:lead, profile: profile, stage: :fresh, ats_type: "workday", description: nil) }

        it "does not call AtsFetcher" do
          expect(Discovery::AtsFetcher).not_to receive(:call)
          described_class.new.perform(lead)
        end
      end

      context "when AtsFetcher returns success: false" do
        let(:lead) { create(:lead, profile: profile, stage: :fresh, ats_type: "ashby", description: nil) }

        before do
          allow(Discovery::AtsFetcher).to receive(:call)
            .and_return({ success: false, response: { error: { message: "Not found" } } })
        end

        it "does not crash" do
          expect { described_class.new.perform(lead) }.not_to raise_error
        end

        it "leaves the lead description unchanged" do
          original = lead.description
          described_class.new.perform(lead)
          expect(lead.reload.description).to eq(original)
        end
      end

      context "when AtsFetcher raises an exception" do
        let(:lead) { create(:lead, profile: profile, stage: :fresh, ats_type: "greenhouse", description: nil) }

        before do
          allow(Discovery::AtsFetcher).to receive(:call).and_raise(RuntimeError, "network timeout")
        end

        it "does not crash the job" do
          expect { described_class.new.perform(lead) }.not_to raise_error
        end

        it "still processes the lead (continues to criterion check)" do
          # Without a criterion the lead auto-passes to reviewed — proving execution continued
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("reviewed")
        end
      end
    end


    context "when the lead has already been evaluated" do
      let(:lead) { create(:lead, profile: profile, stage: :reviewed, evaluated_at: 1.hour.ago) }

      it "does not call KeywordEvaluator" do
        expect(Matching::KeywordEvaluator).not_to receive(:call)
        described_class.new.perform(lead)
      end

      it "does not change the lead stage" do
        expect { described_class.new.perform(lead) }
          .not_to change { lead.reload.stage }
      end
    end

    context "when the profile has no matching criterion" do
      it "does not call KeywordEvaluator" do
        expect(Matching::KeywordEvaluator).not_to receive(:call)
        described_class.new.perform(lead)
      end

      it "moves the lead to :reviewed stage (auto-pass)" do
        described_class.new.perform(lead)
        expect(lead.reload.stage).to eq("reviewed")
      end
    end

    context "when the profile has a matching criterion" do
      let!(:criterion) { create(:matching_criterion, profile: profile) }

      context "when the lead passes keyword evaluation" do
        before do
          allow(Matching::KeywordEvaluator).to receive(:call).and_return(
            { success: true, response: { passed: true, reason: "All keyword checks passed" } }
          )
        end

        it "moves the lead to :reviewed stage" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("reviewed")
        end

        it "does not set match_reasoning" do
          described_class.new.perform(lead)
          expect(lead.reload.match_reasoning).to be_nil
        end
      end

      context "when the lead fails keyword evaluation" do
        before do
          allow(Matching::KeywordEvaluator).to receive(:call).and_return(
            { success: true, response: { passed: false, reason: "Missing required keywords: ruby" } }
          )
        end

        it "moves the lead to :skipped stage" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("skipped")
        end

        it "stores the rejection reason in match_reasoning" do
          described_class.new.perform(lead)
          expect(lead.reload.match_reasoning).to eq("Missing required keywords: ruby")
        end
      end

      context "when KeywordEvaluator returns success: false" do
        before do
          allow(Matching::KeywordEvaluator).to receive(:call).and_return(
            { success: false, response: { error: "unexpected failure" } }
          )
        end

        it "does not change the lead stage" do
          expect { described_class.new.perform(lead) }
            .not_to change { lead.reload.stage }
        end
      end

      context "with real keyword evaluation (integration)" do
        context "when lead contains excluded keywords" do
          let(:lead) do
            create(:lead, profile: profile, stage: :fresh,
              title: "Junior Rails Developer",
              description: "Looking for a junior developer")
          end

          it "moves the lead to :skipped" do
            described_class.new.perform(lead)
            expect(lead.reload.stage).to eq("skipped")
          end

          it "stores the reason mentioning excluded keywords" do
            described_class.new.perform(lead)
            expect(lead.reload.match_reasoning).to include("junior")
          end
        end

        context "when lead contains all required keywords" do
          let(:lead) do
            create(:lead, profile: profile, stage: :fresh,
              title: "Senior Rails Engineer",
              description: "Ruby on Rails with PostgreSQL — remote position")
          end

          it "moves the lead to :reviewed" do
            described_class.new.perform(lead)
            expect(lead.reload.stage).to eq("reviewed")
          end
        end
      end
    end
  end
end
