require "rails_helper"

RSpec.describe Matching::KeywordEvaluator, type: :service do
  describe ".call" do
    let(:profile)   { create(:profile) }
    let(:criterion) { create(:matching_criterion, profile: profile) }

    context "when criterion is nil" do
      it "passes the lead with a 'No criteria set' reason" do
        lead = build(:lead, title: "Software Engineer", description: "Rails job")
        result = described_class.call(lead: lead, criterion: nil)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be true
        expect(result[:response][:reason]).to eq("No criteria set")
      end
    end

    context "when excluded keywords are present in the lead" do
      let(:criterion) do
        create(:matching_criterion, profile: profile,
               excluded_keywords: ["intern", "junior"],
               required_keywords: [])
      end

      it "fails the lead when the title contains an excluded keyword" do
        lead = build(:lead, title: "Junior Rails Engineer", description: "Great role")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be false
        expect(result[:response][:reason]).to include("Excluded keywords found")
        expect(result[:response][:reason]).to include("junior")
      end

      it "fails the lead when the description contains an excluded keyword" do
        lead = build(:lead, title: "Rails Engineer", description: "Internship position available")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be false
        expect(result[:response][:reason]).to include("intern")
      end

      it "is case-insensitive when matching excluded keywords" do
        lead = build(:lead, title: "INTERN Rails Engineer", description: "")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:response][:passed]).to be false
      end
    end

    context "when required keywords are not present in the lead" do
      let(:criterion) do
        create(:matching_criterion, profile: profile,
               required_keywords: ["rails", "postgresql"],
               excluded_keywords: [])
      end

      it "fails the lead when required keywords are missing" do
        lead = build(:lead, title: "Node.js Engineer", description: "JavaScript role")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be false
        expect(result[:response][:reason]).to include("Missing required keywords")
        expect(result[:response][:reason]).to include("rails")
        expect(result[:response][:reason]).to include("postgresql")
      end

      it "fails if only some required keywords are missing" do
        lead = build(:lead, title: "Rails Engineer", description: "No SQL needed")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:response][:passed]).to be false
        expect(result[:response][:reason]).to include("postgresql")
      end

      it "is case-insensitive when matching required keywords" do
        lead = build(:lead, title: "RAILS Engineer", description: "POSTGRESQL database")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:response][:passed]).to be true
      end
    end

    context "when the lead passes all keyword checks" do
      let(:criterion) do
        create(:matching_criterion, profile: profile,
               required_keywords: ["ruby", "rails"],
               excluded_keywords: ["intern"])
      end

      it "passes the lead with 'All keyword checks passed' reason" do
        lead = build(:lead, title: "Ruby on Rails Engineer", description: "Great opportunity")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be true
        expect(result[:response][:reason]).to eq("All keyword checks passed")
      end
    end

    context "when the criterion has no required keywords set" do
      let(:criterion) do
        create(:matching_criterion, profile: profile,
               required_keywords: [],
               excluded_keywords: [])
      end

      it "passes the lead without checking required keywords" do
        lead = build(:lead, title: "Any Engineer", description: "Generic role")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:response][:passed]).to be true
      end
    end

    context "when the lead has nil title or description" do
      let(:criterion) do
        create(:matching_criterion, profile: profile,
               required_keywords: ["rails"],
               excluded_keywords: ["intern"])
      end

      it "handles nil title gracefully" do
        lead = build(:lead, title: nil, description: "A rails position")
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be true
      end

      it "handles nil description gracefully" do
        lead = build(:lead, title: "Rails Engineer", description: nil)
        result = described_class.call(lead: lead, criterion: criterion)

        expect(result[:success]).to be true
        expect(result[:response][:passed]).to be true
      end
    end
  end
end
