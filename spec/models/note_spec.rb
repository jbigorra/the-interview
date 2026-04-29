require "rails_helper"

RSpec.describe Note, type: :model do
  describe "associations" do
    it "belongs to a lead" do
      note = create(:note)
      expect(note.lead).to be_a(Lead)
    end

    it "is destroyed when the lead is destroyed" do
      lead = create(:lead)
      create(:note, lead: lead)
      expect { lead.destroy }.to change(Note, :count).by(-1)
    end
  end

  describe "validations" do
    it "is valid with required attributes" do
      note = build(:note)
      expect(note).to be_valid
    end

    it "requires body" do
      note = build(:note, body: nil)
      expect(note).not_to be_valid
      expect(note.errors[:body]).to include("can't be blank")
    end

    it "requires author" do
      note = build(:note, author: nil)
      expect(note).not_to be_valid
      expect(note.errors[:author]).to include("can't be blank")
    end
  end

  describe "default ordering" do
    it "orders by created_at descending by default" do
      lead = create(:lead)
      older_note = nil
      newer_note = nil

      travel_to(1.hour.ago) { older_note = create(:note, lead: lead) }
      travel_to(Time.current) { newer_note = create(:note, lead: lead) }

      expect(Note.all.first).to eq(newer_note)
      expect(Note.all.last).to eq(older_note)
    end
  end

  describe "persistence" do
    it "persists body content" do
      note = create(:note, body: "This is an important observation about the candidate.")
      expect(note.reload.body).to eq("This is an important observation about the candidate.")
    end

    it "supports system author" do
      note = create(:note, author: "system")
      expect(note.reload.author).to eq("system")
    end

    it "supports user author" do
      note = create(:note, author: "user")
      expect(note.reload.author).to eq("user")
    end
  end
end
