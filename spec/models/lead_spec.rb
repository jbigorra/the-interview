require "rails_helper"

RSpec.describe Lead, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      lead = build(:lead)
      expect(lead).to be_valid
    end

    it "requires url" do
      lead = build(:lead, url: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:url]).to include("can't be blank")
    end

    it "requires fingerprint" do
      lead = build(:lead, url: nil, fingerprint: nil)
      expect(lead).not_to be_valid
      expect(lead.errors[:fingerprint]).to include("can't be blank")
    end

    it "enforces fingerprint uniqueness scoped to profile_id" do
      profile = create(:profile)
      url = "https://jobs.lever.co/acme/abc-123"
      fingerprint = Digest::SHA256.hexdigest(url)
      create(:lead, profile: profile, url: url, fingerprint: fingerprint)

      duplicate = build(:lead, profile: profile, url: url, fingerprint: fingerprint)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:fingerprint]).to include("has already been taken")
    end

    it "allows same fingerprint for different profiles" do
      url = "https://jobs.lever.co/acme/abc-123"
      fingerprint = Digest::SHA256.hexdigest(url)
      profile1 = create(:profile)
      profile2 = create(:profile, email: "other@example.com")

      create(:lead, profile: profile1, url: url, fingerprint: fingerprint)
      lead2 = build(:lead, profile: profile2, url: url, fingerprint: fingerprint)
      expect(lead2).to be_valid
    end
  end

  describe "fingerprint generation" do
    it "auto-generates fingerprint from URL before validation on create" do
      lead = build(:lead, url: "https://jobs.lever.co/acme/unique-id-123", fingerprint: nil)
      lead.valid?
      expect(lead.fingerprint).to eq(Digest::SHA256.hexdigest("https://jobs.lever.co/acme/unique-id-123"))
    end

    it "does not overwrite an existing fingerprint" do
      existing_fingerprint = "abc123"
      lead = build(:lead, fingerprint: existing_fingerprint)
      lead.valid?
      expect(lead.fingerprint).to eq(existing_fingerprint)
    end
  end

  describe "stage enum" do
    it "defaults to fresh stage" do
      lead = build(:lead)
      expect(lead.stage).to eq("fresh")
    end

    it "includes all expected stages" do
      expected_stages = %w[fresh reviewed applied interviewing offered rejected skipped]
      expect(Lead.stages.keys).to match_array(expected_stages)
    end

    it "maps fresh to 0" do
      expect(Lead.stages["fresh"]).to eq(0)
    end

    it "maps skipped to 6" do
      expect(Lead.stages["skipped"]).to eq(6)
    end
  end

  describe "match_recommendation enum" do
    it "accepts apply" do
      lead = build(:lead, match_recommendation: :apply)
      expect(lead).to be_valid
      expect(lead.match_recommendation).to eq("apply")
    end

    it "accepts maybe" do
      lead = build(:lead, match_recommendation: :maybe)
      expect(lead.match_recommendation).to eq("maybe")
    end

    it "accepts skip" do
      lead = build(:lead, match_recommendation: :skip)
      expect(lead.match_recommendation).to eq("skip")
    end
  end

  describe "#move_to!" do
    it "changes the stage to the given value" do
      lead = create(:lead, stage: :fresh)
      lead.move_to!(:reviewed)
      expect(lead.reload.stage).to eq("reviewed")
    end

    it "creates a LeadEvent recording the transition" do
      lead = create(:lead, stage: :fresh)
      expect { lead.move_to!(:applied) }.to change(LeadEvent, :count).by(1)

      event = LeadEvent.last
      expect(event.from_stage).to eq(Lead.stages["fresh"])
      expect(event.to_stage).to eq(Lead.stages["applied"])
      expect(event.trigger).to eq("manual")
    end

    it "returns self" do
      lead = create(:lead, stage: :fresh)
      result = lead.move_to!(:reviewed)
      expect(result).to eq(lead)
    end
  end

  describe "scopes" do
    it "by_stage_position orders by stage_position asc" do
      profile = create(:profile)
      lead_b = create(:lead, profile: profile, stage_position: 2)
      lead_a = create(:lead, profile: profile, stage_position: 1)
      lead_c = create(:lead, profile: profile, stage_position: 3)

      expect(Lead.by_stage_position.to_a).to eq([lead_a, lead_b, lead_c])
    end
  end

  describe "associations" do
    it "belongs to a profile" do
      lead = create(:lead)
      expect(lead.profile).to be_a(Profile)
    end
  end
end
