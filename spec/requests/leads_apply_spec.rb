require "rails_helper"

RSpec.describe "Leads apply flow", type: :request do
  let(:profile) do
    create(:profile,
      email:                 "dev@example.com",
      resume_text:           "10 years Ruby",
      cover_letter_template: "I love working here.",
      personal_info:         { "first_name" => "Dev", "last_name" => "Smith", "phone" => "555-0001" },
      common_answers:        {})
  end

  describe "GET /leads/:id/apply" do
    context "when the lead has a supported ATS (greenhouse)" do
      let(:lead) do
        create(:lead, profile: profile,
          ats_type: "greenhouse",
          url: "https://boards.greenhouse.io/acme/jobs/99")
      end

      it "returns HTTP 200" do
        get apply_lead_path(lead)
        expect(response).to have_http_status(:ok)
      end

      it "shows the company name" do
        get apply_lead_path(lead)
        expect(response.body).to include(lead.company)
      end

      it "shows the job title" do
        get apply_lead_path(lead)
        expect(response.body).to include(lead.title)
      end

      it "shows the pre-filled application section" do
        get apply_lead_path(lead)
        expect(response.body).to include("Pre-filled Application")
      end

      it "displays the email field value" do
        get apply_lead_path(lead)
        expect(response.body).to include("dev@example.com")
      end

      it "shows the Open Form in Browser link" do
        get apply_lead_path(lead)
        expect(response.body).to include("Open Form in Browser")
      end

      it "shows the Mark as Applied button" do
        get apply_lead_path(lead)
        expect(response.body).to include("Mark as Applied")
      end

      it "creates an Application record in draft state" do
        expect { get apply_lead_path(lead) }.to change(Application, :count).by(1)
        expect(Application.last.status).to eq("draft")
      end

      it "does not create a duplicate Application on subsequent visits" do
        get apply_lead_path(lead)
        expect { get apply_lead_path(lead) }.not_to change(Application, :count)
      end

      it "stores the apply_url on the Application" do
        get apply_lead_path(lead)
        expect(Application.last.apply_url).to eq(lead.url)
      end

      it "stores the form_payload on the Application" do
        get apply_lead_path(lead)
        expect(Application.last.form_payload).to be_a(Hash)
        expect(Application.last.form_payload).not_to be_empty
      end
    end

    context "when the lead has a supported ATS (lever)" do
      let(:lead) do
        create(:lead, profile: profile,
          ats_type: "lever",
          url: "https://jobs.lever.co/acme/abc-123")
      end

      it "returns HTTP 200" do
        get apply_lead_path(lead)
        expect(response).to have_http_status(:ok)
      end

      it "shows the pre-filled full name" do
        get apply_lead_path(lead)
        expect(response.body).to include("Dev Smith")
      end
    end

    context "when the lead has a supported ATS (ashby)" do
      let(:lead) do
        create(:lead, profile: profile,
          ats_type: "ashby",
          url: "https://jobs.ashbyhq.com/acme/def-456")
      end

      it "returns HTTP 200" do
        get apply_lead_path(lead)
        expect(response).to have_http_status(:ok)
      end

      it "shows the pre-filled application section" do
        get apply_lead_path(lead)
        expect(response.body).to include("Pre-filled Application")
      end
    end

    context "when the lead has an unsupported ATS" do
      let(:lead) do
        create(:lead, profile: profile,
          ats_type: "workday",
          url: "https://acme.myworkdayjobs.com/jobs/abc")
      end

      it "returns HTTP 200" do
        get apply_lead_path(lead)
        expect(response).to have_http_status(:ok)
      end

      it "shows the fallback message naming the unsupported ATS" do
        get apply_lead_path(lead)
        expect(response.body).to include("Unsupported ATS")
        expect(response.body).to include("workday")
      end

      it "still shows the Open Application Form link" do
        get apply_lead_path(lead)
        expect(response.body).to include("Open Application Form")
      end

      it "still shows the Mark as Applied button" do
        get apply_lead_path(lead)
        expect(response.body).to include("Mark as Applied")
      end

      it "creates an Application with empty form_payload" do
        get apply_lead_path(lead)
        expect(Application.last.form_payload).to eq({})
      end
    end
  end

  describe "POST /leads/:id/submit_application" do
    let(:lead) do
      create(:lead, profile: profile,
        ats_type: "greenhouse",
        url: "https://boards.greenhouse.io/acme/jobs/99",
        stage: :reviewed)
    end

    context "when an Application draft exists" do
      before do
        create(:application, lead: lead, status: :draft)
      end

      it "marks the application as submitted" do
        post submit_application_lead_path(lead)
        expect(lead.application.reload.status).to eq("submitted")
      end

      it "records the submitted_at timestamp" do
        freeze_time do
          post submit_application_lead_path(lead)
          expect(lead.application.reload.submitted_at).to be_within(1.second).of(Time.current)
        end
      end

      it "moves the lead stage to applied" do
        post submit_application_lead_path(lead)
        expect(lead.reload.stage).to eq("applied")
      end

      it "redirects to the lead show page" do
        post submit_application_lead_path(lead)
        expect(response).to redirect_to(lead_path(lead))
      end

      it "sets a success notice" do
        post submit_application_lead_path(lead)
        follow_redirect!
        expect(response.body).to include("marked as submitted")
      end
    end

    context "when no Application draft exists" do
      it "redirects to the lead show page with an alert" do
        post submit_application_lead_path(lead)
        expect(response).to redirect_to(lead_path(lead))
        follow_redirect!
        expect(response.body).to include("No application draft found")
      end
    end
  end
end
