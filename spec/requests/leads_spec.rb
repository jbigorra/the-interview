require "rails_helper"

RSpec.describe "Leads", type: :request do
  let!(:profile) { create(:profile) }
  let!(:lead) { create(:lead, profile: profile, stage: :fresh) }

  describe "GET /leads" do
    it "renders the kanban board" do
      get leads_path
      expect(response).to have_http_status(:ok)
    end

    it "shows leads in their stages" do
      get leads_path
      expect(response.body).to include(lead.title)
    end

    it "shows all stage columns" do
      get leads_path
      expect(response.body).to include("Fresh")
      expect(response.body).to include("Reviewed")
      expect(response.body).to include("Applied")
    end

    context "when no profile exists" do
      before { Profile.destroy_all }

      it "creates a default profile and renders" do
        get leads_path
        expect(response).to have_http_status(:ok)
        expect(Profile.count).to eq(1)
      end
    end
  end

  describe "GET /leads/:id" do
    it "renders the lead detail page" do
      get lead_path(lead)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(lead.title)
    end

    it "shows lead company and location" do
      get lead_path(lead)
      expect(response.body).to include(lead.company)
    end

    it "shows notes section" do
      get lead_path(lead)
      expect(response.body).to include("Notes")
    end

    it "shows existing notes" do
      note = create(:note, lead: lead, body: "Great opportunity")
      get lead_path(lead)
      expect(response.body).to include("Great opportunity")
    end
  end

  describe "PATCH /leads/:id/move" do
    context "with valid stage" do
      it "moves the lead to the new stage" do
        patch move_lead_path(lead), params: { stage: 1, position: 0 }
        expect(lead.reload.stage).to eq("reviewed")
      end

      it "creates a lead event" do
        expect {
          patch move_lead_path(lead), params: { stage: 1, position: 0 }
        }.to change(LeadEvent, :count).by(1)
      end

      it "updates stage_position when position param is present" do
        patch move_lead_path(lead), params: { stage: 1, position: 2 }
        expect(lead.reload.stage_position).to eq(2)
      end

      context "with HTML format" do
        it "redirects to leads path" do
          patch move_lead_path(lead), params: { stage: 1, position: 0 }
          expect(response).to redirect_to(leads_path)
        end
      end

      context "with turbo_stream format" do
        it "responds with turbo stream" do
          patch move_lead_path(lead),
                params: { stage: 1, position: 0 },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        end

        it "includes a replace stream for the lead card" do
          patch move_lead_path(lead),
                params: { stage: 1, position: 0 },
                headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response.body).to include("lead_#{lead.id}")
          expect(response.body).to include("turbo-stream")
        end
      end
    end

    context "with invalid stage" do
      it "does not change the stage when stage is out of range" do
        patch move_lead_path(lead), params: { stage: 999, position: 0 }
        expect(lead.reload.stage).to eq("fresh")
      end

      it "responds with turbo stream error on invalid stage" do
        patch move_lead_path(lead),
              params: { stage: 999, position: 0 },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include("flash")
      end
    end
  end

  describe "DELETE /leads/:id" do
    it "destroys the lead" do
      expect {
        delete lead_path(lead)
      }.to change(Lead, :count).by(-1)
    end

    it "redirects to leads path with notice" do
      delete lead_path(lead)
      expect(response).to redirect_to(leads_path)
      follow_redirect!
      expect(response.body).to include("Lead deleted")
    end
  end
end
