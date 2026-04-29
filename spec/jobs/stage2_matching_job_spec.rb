# frozen_string_literal: true

require "rails_helper"

RSpec.describe Stage2MatchingJob, type: :job do
  let(:profile)   { create(:profile) }
  let(:criterion) { create(:matching_criterion, profile: profile, llm_threshold: 70) }
  let(:lead)      { create(:lead, profile: profile, stage: :reviewed) }

  def successful_llm_result(score:, recommendation: "apply", reasoning: "Good match")
    {
      success: true,
      response: {
        score:          score,
        recommendation: recommendation,
        reasoning:      reasoning,
        strengths:      ["Rails experience"],
        concerns:       []
      }
    }
  end

  describe "job configuration" do
    it "is queued on the :matching queue" do
      expect(described_class.new.queue_name).to eq("matching")
    end
  end

  describe "#perform" do
    context "when the lead already has a match_score" do
      let(:lead) { create(:lead, profile: profile, stage: :reviewed, match_score: 85) }

      it "does not call LlmEvaluator" do
        expect(Matching::LlmEvaluator).not_to receive(:call)
        described_class.new.perform(lead)
      end

      it "does not change the lead stage" do
        expect { described_class.new.perform(lead) }
          .not_to change { lead.reload.stage }
      end
    end

    context "when the profile has no matching criterion" do
      it "does not call LlmEvaluator" do
        expect(Matching::LlmEvaluator).not_to receive(:call)
        described_class.new.perform(lead)
      end

      it "moves the lead to :reviewed (auto-pass)" do
        described_class.new.perform(lead)
        expect(lead.reload.stage).to eq("reviewed")
      end
    end

    context "when the profile has a matching criterion" do
      before { criterion }

      context "when the score is above the threshold (score >= 70)" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call)
            .and_return(successful_llm_result(score: 85))
        end

        it "moves the lead to :reviewed" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("reviewed")
        end

        it "persists match_score" do
          described_class.new.perform(lead)
          expect(lead.reload.match_score).to eq(85)
        end

        it "persists match_reasoning" do
          described_class.new.perform(lead)
          expect(lead.reload.match_reasoning).to eq("Good match")
        end

        it "sets evaluated_at" do
          freeze_time do
            described_class.new.perform(lead)
            expect(lead.reload.evaluated_at).to be_within(1.second).of(Time.current)
          end
        end
      end

      context "when the score is borderline (within 20 points below threshold: 50 <= score < 70)" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call)
            .and_return(successful_llm_result(score: 55, recommendation: "maybe", reasoning: "Borderline fit"))
        end

        it "moves the lead to :reviewed for manual review" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("reviewed")
        end

        it "persists the match_score" do
          described_class.new.perform(lead)
          expect(lead.reload.match_score).to eq(55)
        end
      end

      context "when the score is below the threshold by more than 20 (score < 50)" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call)
            .and_return(successful_llm_result(score: 30, recommendation: "skip", reasoning: "Poor fit"))
        end

        it "moves the lead to :skipped" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("skipped")
        end

        it "persists the match_score" do
          described_class.new.perform(lead)
          expect(lead.reload.match_score).to eq(30)
        end
      end

      context "when the score is exactly at the threshold (score == 70)" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call)
            .and_return(successful_llm_result(score: 70))
        end

        it "moves the lead to :reviewed" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("reviewed")
        end
      end

      context "when the score is exactly 20 below the threshold (score == 50)" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call)
            .and_return(successful_llm_result(score: 50, recommendation: "maybe"))
        end

        it "moves the lead to :reviewed (borderline — within 20 points)" do
          described_class.new.perform(lead)
          expect(lead.reload.stage).to eq("reviewed")
        end
      end

      context "when LlmEvaluator returns success: false" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call).and_return(
            { success: false, response: { error: { message: "Timeout connecting to API" } } }
          )
        end

        it "raises an error (triggering retry)" do
          expect { described_class.new.perform(lead) }.to raise_error("Timeout connecting to API")
        end

        it "does not change the lead stage" do
          expect { described_class.new.perform(lead) rescue nil }
            .not_to change { lead.reload.stage }
        end

        it "does not set match_score (preserves pending evaluation state)" do
          described_class.new.perform(lead) rescue nil
          expect(lead.reload.match_score).to be_nil
        end
      end

      context "when LlmEvaluator raises RubyLLM::Error" do
        before do
          allow(Matching::LlmEvaluator).to receive(:call)
            .and_raise(RubyLLM::Error, "Rate limit exceeded")
        end

        it "re-raises the error so the discard_on handler can act" do
          expect { described_class.new.perform(lead) }.to raise_error(RubyLLM::Error)
        end
      end

      context "when criterion has a custom threshold of 80" do
        let(:criterion) { create(:matching_criterion, profile: profile, llm_threshold: 80) }

        context "when score is 65 (borderline: within 20 of 80)" do
          before do
            allow(Matching::LlmEvaluator).to receive(:call)
              .and_return(successful_llm_result(score: 65, recommendation: "maybe"))
          end

          it "moves the lead to :reviewed" do
            described_class.new.perform(lead)
            expect(lead.reload.stage).to eq("reviewed")
          end
        end

        context "when score is 59 (more than 20 below threshold)" do
          before do
            allow(Matching::LlmEvaluator).to receive(:call)
              .and_return(successful_llm_result(score: 59, recommendation: "skip"))
          end

          it "moves the lead to :skipped" do
            described_class.new.perform(lead)
            expect(lead.reload.stage).to eq("skipped")
          end
        end
      end
    end
  end
end
