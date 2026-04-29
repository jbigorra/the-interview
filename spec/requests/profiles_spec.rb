require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let!(:profile) { create(:profile) }

  describe "GET /profile" do
    it "renders successfully" do
      get profile_path
      expect(response).to have_http_status(:ok)
    end

    it "shows the profile form" do
      get profile_path
      expect(response.body).to include("Profile & Matching Criteria")
    end

    it "shows the profile full name" do
      get profile_path
      expect(response.body).to include(profile.full_name)
    end

    context "when no profile exists" do
      before { Profile.destroy_all }

      it "creates a default profile and renders" do
        get profile_path
        expect(response).to have_http_status(:ok)
        expect(Profile.count).to eq(1)
      end
    end

    context "when profile has a matching criterion" do
      let!(:criterion) { create(:matching_criterion, profile: profile) }

      it "shows the criteria form fields" do
        get profile_path
        expect(response.body).to include("LLM Match Threshold")
      end
    end
  end

  describe "PATCH /profile" do
    context "with valid params" do
      let(:valid_params) do
        {
          profile: {
            full_name: "Jane Smith",
            email: "jane@example.com",
            resume_text: "Updated resume",
            matching_criterion_attributes: {
              required_keywords: "Ruby, Rails",
              excluded_keywords: "intern",
              min_salary: "130000",
              preferred_locations: "US, Remote",
              work_mode: "remote",
              llm_threshold: "75"
            }
          }
        }
      end

      it "updates the profile and redirects" do
        patch profile_path, params: valid_params
        expect(response).to redirect_to(profile_path)
      end

      it "shows a success notice after redirect" do
        patch profile_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("Profile updated")
      end

      it "updates the profile full_name" do
        patch profile_path, params: valid_params
        expect(profile.reload.full_name).to eq("Jane Smith")
      end

      it "creates a matching criterion when none exists" do
        expect {
          patch profile_path, params: valid_params
        }.to change(MatchingCriterion, :count).by(1)
      end

      it "converts comma-separated required_keywords to an array" do
        patch profile_path, params: valid_params
        expect(profile.reload.matching_criterion.required_keywords).to eq(%w[Ruby Rails])
      end

      it "converts comma-separated excluded_keywords to an array" do
        patch profile_path, params: valid_params
        expect(profile.reload.matching_criterion.excluded_keywords).to eq(%w[intern])
      end

      it "converts comma-separated preferred_locations to an array" do
        patch profile_path, params: valid_params
        expect(profile.reload.matching_criterion.preferred_locations).to eq(%w[US Remote])
      end

      context "when a matching criterion already exists" do
        let!(:criterion) { create(:matching_criterion, profile: profile) }

        let(:update_params) do
          {
            profile: {
              full_name: "Jane Smith",
              email: "jane@example.com",
              matching_criterion_attributes: {
                id: criterion.id,
                required_keywords: "Elixir, Phoenix",
                excluded_keywords: "",
                preferred_locations: "EU",
                work_mode: "hybrid",
                llm_threshold: "80"
              }
            }
          }
        end

        it "updates the existing criterion instead of creating a new one" do
          expect {
            patch profile_path, params: update_params
          }.not_to change(MatchingCriterion, :count)
        end

        it "updates the llm_threshold" do
          patch profile_path, params: update_params
          expect(criterion.reload.llm_threshold).to eq(80)
        end
      end
    end

    context "with invalid threshold" do
      let(:invalid_params) do
        {
          profile: {
            full_name: "Jane Smith",
            email: "jane@example.com",
            matching_criterion_attributes: {
              llm_threshold: "150"
            }
          }
        }
      end

      it "returns unprocessable_entity status" do
        patch profile_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "re-renders the show page" do
        patch profile_path, params: invalid_params
        expect(response.body).to include("Profile & Matching Criteria")
      end
    end

    context "with invalid profile params (blank full_name)" do
      let(:invalid_params) do
        {
          profile: {
            full_name: "",
            email: "jane@example.com"
          }
        }
      end

      it "returns unprocessable_entity status" do
        patch profile_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
