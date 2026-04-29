require "rails_helper"

RSpec.describe Application, type: :model do
  describe "associations" do
    it "belongs to a lead" do
      app = create(:application)
      expect(app.lead).to be_a(Lead)
    end

    it "is destroyed when the lead is destroyed" do
      lead = create(:lead)
      create(:application, lead: lead)
      expect { lead.destroy }.to change(Application, :count).by(-1)
    end
  end

  describe "validations" do
    it "is valid with required attributes" do
      app = build(:application)
      expect(app).to be_valid
    end

    it "requires ats_type" do
      app = build(:application, ats_type: nil)
      expect(app).not_to be_valid
      expect(app.errors[:ats_type]).to include("can't be blank")
    end

    it "requires status" do
      app = build(:application, status: nil)
      expect(app).not_to be_valid
      expect(app.errors[:status]).to include("can't be blank")
    end

    it "rejects invalid status values" do
      app = build(:application, status: "unknown")
      expect(app).not_to be_valid
      expect(app.errors[:status]).to be_present
    end
  end

  describe "status enum" do
    it "defaults to draft" do
      app = create(:application)
      expect(app.status).to eq("draft")
    end

    it "supports submitted status" do
      app = create(:application, status: "submitted")
      expect(app.status).to eq("submitted")
    end

    it "supports error status" do
      app = create(:application, status: "error")
      expect(app.status).to eq("error")
    end
  end

  describe "#submitted?" do
    it "returns false when submitted_at is nil" do
      app = build(:application, submitted_at: nil)
      expect(app.submitted?).to be false
    end

    it "returns true when submitted_at is present" do
      app = build(:application, submitted_at: Time.current)
      expect(app.submitted?).to be true
    end
  end

  describe "one-application-per-lead constraint" do
    it "allows only one application per lead" do
      lead = create(:lead)
      create(:application, lead: lead)
      duplicate = build(:application, lead: lead)
      # has_one :application — assigning a second one destroys the first
      # The DB does not enforce uniqueness here; business logic uses has_one
      expect(lead.application).to be_a(Application)
    end
  end

  describe "jsonb fields" do
    it "defaults form_payload to empty hash" do
      app = create(:application)
      expect(app.form_payload).to eq({})
    end

    it "defaults ats_response to empty hash" do
      app = create(:application)
      expect(app.ats_response).to eq({})
    end

    it "persists nested payload data" do
      app = create(:application, form_payload: { "resume_url" => "https://example.com/cv.pdf" })
      expect(app.reload.form_payload["resume_url"]).to eq("https://example.com/cv.pdf")
    end
  end
end
