# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stage1MatchingJob, type: :job do
  let(:profile) { create(:profile) }
  let(:lead) { create(:lead, profile: profile, stage: :fresh, description: "Rails Ruby PostgreSQL remote role") }

  describe "#perform" do
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
