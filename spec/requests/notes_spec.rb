require "rails_helper"

RSpec.describe "Notes", type: :request do
  let!(:profile) { create(:profile) }
  let!(:lead) { create(:lead, profile: profile) }

  describe "POST /leads/:lead_id/notes" do
    context "with valid body" do
      let(:valid_params) { { note: { body: "This is a great opportunity" } } }

      it "creates a note" do
        expect {
          post lead_notes_path(lead), params: valid_params
        }.to change(Note, :count).by(1)
      end

      it "sets author to user" do
        post lead_notes_path(lead), params: valid_params
        expect(Note.last.author).to eq("user")
      end

      it "associates the note with the lead" do
        post lead_notes_path(lead), params: valid_params
        expect(Note.last.lead).to eq(lead)
      end

      context "with HTML format" do
        it "redirects to lead path with notice" do
          post lead_notes_path(lead), params: valid_params
          expect(response).to redirect_to(lead_path(lead))
          follow_redirect!
          expect(response.body).to include("Note added")
        end
      end

      context "with turbo_stream format" do
        it "responds with turbo stream" do
          post lead_notes_path(lead),
               params: valid_params,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response).to have_http_status(:ok)
          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        end

        it "appends the note to notes_list" do
          post lead_notes_path(lead),
               params: valid_params,
               headers: { "Accept" => "text/vnd.turbo-stream.html" }
          expect(response.body).to include("notes_list")
          expect(response.body).to include("turbo-stream")
        end
      end
    end

    context "with invalid body (blank)" do
      let(:invalid_params) { { note: { body: "" } } }

      it "does not create a note" do
        expect {
          post lead_notes_path(lead), params: invalid_params
        }.not_to change(Note, :count)
      end

      it "responds with turbo stream to replace the form" do
        post lead_notes_path(lead),
             params: invalid_params,
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.body).to include("new_note")
        expect(response.body).to include("turbo-stream")
      end
    end
  end
end
