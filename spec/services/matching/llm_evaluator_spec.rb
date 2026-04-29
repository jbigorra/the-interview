require "rails_helper"

RSpec.describe Matching::LlmEvaluator, type: :service do
  let(:profile)   { create(:profile) }
  let(:criterion) { create(:matching_criterion, profile: profile) }
  let(:lead) do
    build(:lead,
      title: "Senior Rails Engineer",
      company: "Acme Corp",
      location: "Remote",
      description: "We are looking for a senior Rails engineer with PostgreSQL experience.")
  end

  let(:valid_llm_response_json) do
    JSON.generate(
      score: 85,
      recommendation: "apply",
      reasoning: "Strong keyword match and remote-friendly.",
      strengths: [ "Rails", "PostgreSQL" ],
      concerns: [ "No mention of salary" ]
    )
  end

  let(:mock_message) { instance_double(RubyLLM::Message, content: valid_llm_response_json) }
  let(:mock_chat)    { instance_double(RubyLLM::Chat) }

  before do
    allow(RubyLLM).to receive(:chat).with(model: Matching::LlmEvaluator::MODEL).and_return(mock_chat)
    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(mock_message)
  end

  describe ".call" do
    context "when the LLM returns a valid structured JSON response" do
      it "returns success: true" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:success]).to be true
      end

      it "returns the parsed score" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:score]).to eq(85)
      end

      it "returns the parsed recommendation" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:recommendation]).to eq("apply")
      end

      it "returns the parsed reasoning" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:reasoning]).to eq("Strong keyword match and remote-friendly.")
      end

      it "returns the parsed strengths array" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:strengths]).to eq([ "Rails", "PostgreSQL" ])
      end

      it "returns the parsed concerns array" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:concerns]).to eq([ "No mention of salary" ])
      end
    end

    context "when the LLM wraps the JSON in markdown code fences" do
      let(:wrapped_json) do
        "```json\n#{valid_llm_response_json}\n```"
      end
      let(:mock_message) { instance_double(RubyLLM::Message, content: wrapped_json) }

      it "strips the markdown fences and returns success: true" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:success]).to be true
        expect(result[:response][:score]).to eq(85)
      end
    end

    context "when the LLM response is missing optional strengths and concerns" do
      let(:minimal_json) do
        JSON.generate(
          score: 60,
          recommendation: "maybe",
          reasoning: "Partial match.",
          strengths: [],
          concerns: []
        )
      end
      let(:mock_message) { instance_double(RubyLLM::Message, content: minimal_json) }

      it "defaults strengths to an empty array" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:strengths]).to eq([])
      end

      it "defaults concerns to an empty array" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:concerns]).to eq([])
      end
    end

    context "when the LLM raises a RubyLLM::Error" do
      before do
        allow(mock_chat).to receive(:ask).and_raise(RubyLLM::Error, "Anthropic API unavailable")
      end

      it "returns success: false" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:success]).to be false
      end

      it "includes the API error message" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:error][:message]).to include("LLM API error")
        expect(result[:response][:error][:message]).to include("Anthropic API unavailable")
      end
    end

    context "when the LLM returns invalid JSON" do
      let(:mock_message) { instance_double(RubyLLM::Message, content: "This is not JSON at all") }

      it "returns success: false" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:success]).to be false
      end

      it "includes a parse error message" do
        result = described_class.call(lead: lead, criterion: criterion)
        expect(result[:response][:error][:message]).to include("Failed to parse LLM response")
      end
    end

    context "when criterion is nil" do
      it "does not raise an error" do
        expect { described_class.call(lead: lead, criterion: nil) }.not_to raise_error
      end

      it "still builds a prompt and calls the LLM" do
        described_class.call(lead: lead, criterion: nil)
        expect(mock_chat).to have_received(:ask)
      end
    end
  end

  describe ".build_prompt" do
    it "includes the lead title" do
      prompt = described_class.build_prompt(lead, criterion)
      expect(prompt).to include("Senior Rails Engineer")
    end

    it "includes the lead company" do
      prompt = described_class.build_prompt(lead, criterion)
      expect(prompt).to include("Acme Corp")
    end

    it "includes the lead description" do
      prompt = described_class.build_prompt(lead, criterion)
      expect(prompt).to include("senior Rails engineer")
    end

    it "includes required keywords from criterion" do
      prompt = described_class.build_prompt(lead, criterion)
      expect(prompt).to include("Ruby")
      expect(prompt).to include("Rails")
    end

    it "handles nil lead title gracefully" do
      lead_without_title = build(:lead, title: nil)
      prompt = described_class.build_prompt(lead_without_title, criterion)
      expect(prompt).to include("Unknown")
    end

    it "handles nil criterion gracefully" do
      prompt = described_class.build_prompt(lead, nil)
      expect(prompt).to include("Not specified")
    end

    context "when lead description exceeds MAX_CHARS" do
      let(:long_description) { "x" * (Matching::LlmEvaluator::MAX_CHARS + 100) }
      let(:lead_with_long_desc) { build(:lead, description: long_description) }

      it "truncates the description and appends an ellipsis" do
        prompt = described_class.build_prompt(lead_with_long_desc, criterion)
        expect(prompt).to include("...")
        expect(prompt).not_to include("x" * (Matching::LlmEvaluator::MAX_CHARS + 10))
      end
    end
  end
end
