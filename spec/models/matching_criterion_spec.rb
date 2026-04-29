require "rails_helper"

RSpec.describe MatchingCriterion, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      criterion = build(:matching_criterion)
      expect(criterion).to be_valid
    end

    it "requires a profile" do
      criterion = build(:matching_criterion, profile: nil)
      expect(criterion).not_to be_valid
    end

    it "validates work_mode inclusion" do
      criterion = build(:matching_criterion, work_mode: "invalid")
      expect(criterion).not_to be_valid
      expect(criterion.errors[:work_mode]).to be_present
    end

    it "accepts valid work_modes" do
      %w[remote hybrid onsite].each do |mode|
        criterion = build(:matching_criterion, work_mode: mode)
        expect(criterion).to be_valid
      end
    end

    it "validates llm_threshold is between 0 and 100" do
      criterion = build(:matching_criterion, llm_threshold: 150)
      expect(criterion).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a profile" do
      criterion = create(:matching_criterion)
      expect(criterion.profile).to be_a(Profile)
    end
  end

  describe "columns" do
    it "has required_keywords array column defaulting to empty array" do
      profile = create(:profile)
      criterion = MatchingCriterion.create!(profile: profile)
      expect(criterion.required_keywords).to eq([])
    end

    it "has excluded_keywords array column defaulting to empty array" do
      profile = create(:profile)
      criterion = MatchingCriterion.create!(profile: profile)
      expect(criterion.excluded_keywords).to eq([])
    end

    it "has preferred_locations array column defaulting to empty array" do
      profile = create(:profile)
      criterion = MatchingCriterion.create!(profile: profile)
      expect(criterion.preferred_locations).to eq([])
    end

    it "defaults work_mode to remote" do
      profile = create(:profile)
      criterion = MatchingCriterion.create!(profile: profile)
      expect(criterion.work_mode).to eq("remote")
    end

    it "defaults llm_threshold to 70" do
      profile = create(:profile)
      criterion = MatchingCriterion.create!(profile: profile)
      expect(criterion.llm_threshold).to eq(70)
    end
  end
end
