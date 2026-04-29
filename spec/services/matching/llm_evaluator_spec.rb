require "rails_helper"

RSpec.describe Matching::LlmEvaluator, type: :service do
  describe ".call" do
    let(:profile)   { create(:profile) }
    let(:criterion) { create(:matching_criterion, profile: profile) }
    let(:lead)      { build(:lead, title: "Rails Engineer", description: "Great role") }

    it "returns success: false" do
      result = described_class.call(lead: lead, criterion: criterion)
      expect(result[:success]).to be false
    end

    it "returns the not-yet-implemented error message" do
      result = described_class.call(lead: lead, criterion: criterion)
      expect(result[:response][:error][:message]).to eq(
        "Not yet implemented — requires ruby_llm + API key"
      )
    end

    it "responds to .call with lead and criterion keyword arguments" do
      expect { described_class.call(lead: lead, criterion: criterion) }.not_to raise_error
    end
  end
end
