require "rails_helper"

RSpec.describe Apply::BaseAdapter, type: :service do
  # Use a concrete double to test the abstract base class behaviour
  # without triggering NotImplementedError on every method call.
  let(:concrete_adapter_class) do
    Class.new(described_class) do
      def extract_fields = raise NotImplementedError, Apply::BaseAdapter::NOT_IMPLEMENTED
      def build_payload   = raise NotImplementedError, Apply::BaseAdapter::NOT_IMPLEMENTED
      def apply_url       = raise NotImplementedError, Apply::BaseAdapter::NOT_IMPLEMENTED
    end
  end

  let(:profile) do
    create(:profile,
      email:                "jane@example.com",
      resume_text:          "Jane's resume",
      cover_letter_template: "Dear Hiring Manager, Jane here.",
      personal_info:        { "first_name" => "Jane", "last_name" => "Doe", "phone" => "555-1234" },
      common_answers:       { "work_authorization" => "yes", "years_experience" => "5" })
  end

  let(:lead) { create(:lead, profile: profile, url: "https://jobs.lever.co/acme/123") }

  subject(:adapter) { concrete_adapter_class.new(lead: lead, profile: profile) }

  describe "#extract_fields" do
    it "raises NotImplementedError" do
      expect { adapter.extract_fields }.to raise_error(NotImplementedError, /Subclasses must implement/)
    end
  end

  describe "#build_payload" do
    it "raises NotImplementedError" do
      expect { adapter.build_payload }.to raise_error(NotImplementedError, /Subclasses must implement/)
    end
  end

  describe "#apply_url" do
    it "raises NotImplementedError" do
      expect { adapter.apply_url }.to raise_error(NotImplementedError, /Subclasses must implement/)
    end
  end

  describe "#standard_fields (via subclass)" do
    # Expose the protected method through a concrete subclass for inspection
    let(:inspecting_adapter_class) do
      Class.new(described_class) do
        def extract_fields  = {}
        def build_payload   = {}
        def apply_url       = lead.url
        def exposed_standard_fields = standard_fields
      end
    end

    subject(:adapter) { inspecting_adapter_class.new(lead: lead, profile: profile) }

    it "maps profile email" do
      expect(adapter.exposed_standard_fields[:email]).to eq("jane@example.com")
    end

    it "maps first_name from personal_info" do
      expect(adapter.exposed_standard_fields[:first_name]).to eq("Jane")
    end

    it "maps last_name from personal_info" do
      expect(adapter.exposed_standard_fields[:last_name]).to eq("Doe")
    end

    it "maps phone from personal_info" do
      expect(adapter.exposed_standard_fields[:phone]).to eq("555-1234")
    end

    it "maps resume_text to :resume" do
      expect(adapter.exposed_standard_fields[:resume]).to eq("Jane's resume")
    end

    it "maps cover_letter_template to :cover_letter" do
      expect(adapter.exposed_standard_fields[:cover_letter]).to eq("Dear Hiring Manager, Jane here.")
    end

    it "compacts nil values from personal_info" do
      profile_without_phone = create(:profile,
        email:        "x@example.com",
        personal_info: { "first_name" => "X" })
      adapter_no_phone = inspecting_adapter_class.new(lead: lead, profile: profile_without_phone)

      expect(adapter_no_phone.exposed_standard_fields).not_to have_key(:phone)
    end

    context "when personal_info is nil" do
      let(:profile) { create(:profile, email: "blank@example.com", personal_info: nil) }

      it "returns only keys that have values" do
        fields = adapter.exposed_standard_fields
        expect(fields).not_to have_key(:first_name)
        expect(fields).not_to have_key(:last_name)
        expect(fields).not_to have_key(:phone)
        expect(fields[:email]).to eq("blank@example.com")
      end
    end
  end

  describe "#common_answers (via subclass)" do
    let(:inspecting_adapter_class) do
      Class.new(described_class) do
        def extract_fields  = {}
        def build_payload   = {}
        def apply_url       = lead.url
        def exposed_common_answers = common_answers
      end
    end

    subject(:adapter) { inspecting_adapter_class.new(lead: lead, profile: profile) }

    it "returns the profile common_answers hash" do
      expect(adapter.exposed_common_answers).to eq(
        "work_authorization" => "yes",
        "years_experience"   => "5"
      )
    end

    context "when profile common_answers is nil" do
      let(:profile) { create(:profile, common_answers: nil) }

      it "returns an empty hash" do
        expect(adapter.exposed_common_answers).to eq({})
      end
    end
  end
end
