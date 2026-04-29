require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let!(:profile) { create(:profile) }

  describe "GET /" do
    it "renders successfully" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "shows search queries" do
      create(:search_query, profile: profile, title: "Rails Engineer")
      get root_path
      expect(response.body).to include("Rails Engineer")
    end

    it "shows leads by stage summary" do
      create(:lead, profile: profile, stage: :fresh)
      create(:lead, profile: profile, stage: :applied)
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "shows recent leads" do
      create(:lead, profile: profile, title: "Ruby Developer", company: "Acme Corp")
      get root_path
      expect(response.body).to include("Ruby Developer")
    end

    context "when no profile exists" do
      before { Profile.destroy_all }

      it "creates a default profile and renders" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(Profile.count).to eq(1)
      end
    end
  end
end
