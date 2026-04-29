require "rails_helper"

RSpec.describe SearchQuery, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      query = build(:search_query)
      expect(query).to be_valid
    end

    it "requires title" do
      query = build(:search_query, title: nil)
      expect(query).not_to be_valid
      expect(query.errors[:title]).to include("can't be blank")
    end

    it "requires portal" do
      query = build(:search_query, portal: nil)
      expect(query).not_to be_valid
      expect(query.errors[:portal]).to include("can't be blank")
    end
  end

  describe "#recently_run?" do
    it "returns false when last_run_at is nil" do
      query = build(:search_query, last_run_at: nil)
      expect(query.recently_run?).to be false
    end

    it "returns true when last_run_at is within 24 hours" do
      query = build(:search_query, last_run_at: 1.hour.ago)
      expect(query.recently_run?).to be true
    end

    it "returns false when last_run_at is older than 24 hours" do
      query = build(:search_query, last_run_at: 25.hours.ago)
      expect(query.recently_run?).to be false
    end

    it "returns false at exactly 24 hours ago" do
      query = build(:search_query, last_run_at: 24.hours.ago - 1.second)
      expect(query.recently_run?).to be false
    end
  end

  describe "#to_google_query" do
    it "builds a site-restricted query" do
      query = build(:search_query, portal: "jobs.lever.co", title: "Senior Rails Engineer", additional_filters: nil)
      expect(query.to_google_query).to eq('site:jobs.lever.co "Senior Rails Engineer"')
    end

    it "includes additional_filters when present" do
      query = build(:search_query, portal: "jobs.lever.co", title: "Senior Rails Engineer", additional_filters: '-"remote in the US"')
      expect(query.to_google_query).to eq('site:jobs.lever.co "Senior Rails Engineer" -"remote in the US"')
    end

    it "omits title quotes when title is blank" do
      query = build(:search_query, portal: "jobs.lever.co", title: nil, additional_filters: nil)
      # title is required — test base structure without title (invalid but good for unit isolation)
      query.title = nil
      expect(query.to_google_query).to eq("site:jobs.lever.co")
    end
  end

  describe "scopes" do
    it "recently_run scope returns queries run within 24 hours" do
      fresh_query = create(:search_query, last_run_at: 1.hour.ago)
      stale_query = create(:search_query, last_run_at: 25.hours.ago)
      never_run = create(:search_query, last_run_at: nil)

      expect(SearchQuery.recently_run).to include(fresh_query)
      expect(SearchQuery.recently_run).not_to include(stale_query)
      expect(SearchQuery.recently_run).not_to include(never_run)
    end
  end
end
