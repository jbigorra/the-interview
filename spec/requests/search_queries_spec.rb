require "rails_helper"

RSpec.describe "SearchQueries", type: :request do
  let!(:profile) { create(:profile) }

  describe "GET /search_queries/new" do
    it "renders the new form" do
      get new_search_query_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /search_queries" do
    context "with valid params" do
      let(:valid_params) do
        { search_query: { title: "Senior Rails Engineer", portal: "jobs.lever.co", additional_filters: "-junior" } }
      end

      it "creates a search query and redirects to root" do
        expect {
          post search_queries_path, params: valid_params
        }.to change(SearchQuery, :count).by(1)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Search query created.")
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        { search_query: { title: "", portal: "" } }
      end

      it "renders new with unprocessable_entity" do
        post search_queries_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /search_queries/:id/edit" do
    let!(:query) { create(:search_query, profile: profile) }

    it "renders the edit form" do
      get edit_search_query_path(query)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PUT /search_queries/:id" do
    let!(:query) { create(:search_query, profile: profile) }

    context "with valid params" do
      it "updates the query and redirects to root" do
        put search_query_path(query), params: { search_query: { title: "Updated Title" } }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Search query updated.")
        expect(query.reload.title).to eq("Updated Title")
      end
    end

    context "with invalid params" do
      it "renders edit with unprocessable_entity" do
        put search_query_path(query), params: { search_query: { title: "", portal: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /search_queries/:id" do
    let!(:query) { create(:search_query, profile: profile) }

    it "destroys the query and redirects to root" do
      expect {
        delete search_query_path(query)
      }.to change(SearchQuery, :count).by(-1)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("Search query deleted.")
    end
  end

  describe "POST /search_queries/:id/run" do
    let!(:query) { create(:search_query, profile: profile, run_count: 0, last_run_at: nil) }

    it "enqueues a DiscoveryJob and redirects to root" do
      expect { post run_search_query_path(query) }
        .to have_enqueued_job(DiscoveryJob).with(query)

      expect(response).to redirect_to(root_path)
    end

    it "shows a notice that the discovery job was enqueued" do
      post run_search_query_path(query)
      follow_redirect!
      expect(response.body).to include("Discovery job enqueued")
    end

    context "when the query was recently run" do
      before { query.update!(last_run_at: 1.hour.ago) }

      it "does not enqueue a DiscoveryJob" do
        expect { post run_search_query_path(query) }
          .not_to have_enqueued_job(DiscoveryJob)
      end

      it "shows an alert about the cooldown" do
        post run_search_query_path(query)
        follow_redirect!
        expect(response.body).to include("recently run")
      end
    end
  end
end
