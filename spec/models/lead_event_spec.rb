require "rails_helper"

RSpec.describe LeadEvent, type: :model do
  describe "associations" do
    it "belongs to a lead" do
      event = create(:lead_event)
      expect(event.lead).to be_a(Lead)
    end

    it "is destroyed when the lead is destroyed" do
      lead = create(:lead)
      create(:lead_event, lead: lead)
      expect { lead.destroy }.to change(LeadEvent, :count).by(-1)
    end
  end

  describe "validations" do
    it "is valid with required attributes" do
      event = build(:lead_event)
      expect(event).to be_valid
    end

    it "requires to_stage" do
      event = build(:lead_event, to_stage: nil)
      expect(event).not_to be_valid
      expect(event.errors[:to_stage]).to include("can't be blank")
    end

    it "requires trigger" do
      event = build(:lead_event, trigger: nil)
      expect(event).not_to be_valid
      expect(event.errors[:trigger]).to include("can't be blank")
    end

    it "allows from_stage to be nil (initial placement)" do
      event = build(:lead_event, from_stage: nil)
      expect(event).to be_valid
    end
  end

  describe "default ordering" do
    it "orders by created_at descending by default" do
      lead = create(:lead)
      older_event = nil
      newer_event = nil

      travel_to(1.hour.ago) { older_event = create(:lead_event, lead: lead) }
      travel_to(Time.current) { newer_event = create(:lead_event, lead: lead) }

      expect(LeadEvent.all.first).to eq(newer_event)
      expect(LeadEvent.all.last).to eq(older_event)
    end
  end

  describe "stage transition persistence" do
    it "records integer from_stage and to_stage values" do
      event = create(:lead_event, from_stage: Lead.stages["fresh"], to_stage: Lead.stages["reviewed"])
      expect(event.reload.from_stage).to eq(0)
      expect(event.reload.to_stage).to eq(1)
    end

    it "persists trigger value" do
      event = create(:lead_event, trigger: "auto_match")
      expect(event.reload.trigger).to eq("auto_match")
    end
  end

  describe "Lead#move_to! integration" do
    it "creates a lead_event with correct stage integers when lead moves" do
      lead = create(:lead, stage: :fresh)
      lead.move_to!(:interviewing)

      event = LeadEvent.first
      expect(event.from_stage).to eq(Lead.stages["fresh"])
      expect(event.to_stage).to eq(Lead.stages["interviewing"])
      expect(event.trigger).to eq("manual")
    end
  end
end
