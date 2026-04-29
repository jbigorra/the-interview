require "rails_helper"

RSpec.describe Profile, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      profile = build(:profile)
      expect(profile).to be_valid
    end

    it "requires full_name" do
      profile = build(:profile, full_name: nil)
      expect(profile).not_to be_valid
      expect(profile.errors[:full_name]).to include("can't be blank")
    end

    it "requires email" do
      profile = build(:profile, email: nil)
      expect(profile).not_to be_valid
      expect(profile.errors[:email]).to include("can't be blank")
    end
  end

  describe "associations" do
    it "has one matching_criterion" do
      profile = create(:profile)
      criterion = create(:matching_criterion, profile: profile)
      expect(profile.matching_criterion).to eq(criterion)
    end

    it "has many search_queries" do
      profile = create(:profile)
      query = create(:search_query, profile: profile)
      expect(profile.search_queries).to include(query)
    end

    it "has many leads" do
      profile = create(:profile)
      lead = create(:lead, profile: profile)
      expect(profile.leads).to include(lead)
    end

    it "destroys dependent matching_criterion on destroy" do
      profile = create(:profile)
      create(:matching_criterion, profile: profile)
      expect { profile.destroy }.to change(MatchingCriterion, :count).by(-1)
    end

    it "destroys dependent leads on destroy" do
      profile = create(:profile)
      create(:lead, profile: profile)
      expect { profile.destroy }.to change(Lead, :count).by(-1)
    end
  end

  describe "columns" do
    it "has a jsonb common_answers column defaulting to empty hash" do
      profile = create(:profile)
      expect(profile.common_answers).to eq({})
    end

    it "has a jsonb personal_info column defaulting to empty hash" do
      profile = create(:profile)
      expect(profile.personal_info).to eq({})
    end
  end
end
