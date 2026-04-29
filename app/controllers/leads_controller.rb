# typed: false

class LeadsController < ApplicationController
  def index
    @profile = Profile.first_or_create!(full_name: "Your Name", email: "you@example.com")
    @leads_by_stage = Lead.where(profile: @profile)
                          .order(:stage_position)
                          .group_by(&:stage)
  end

  def show
    @lead = Lead.find(params[:id])
    @notes = @lead.notes.to_a
    @note = Note.new(lead: @lead)
  end

  def move
    @lead = Lead.find(params[:id])

    begin
      @lead.move_to!(params[:stage].to_i)
      @lead.update!(stage_position: params[:position].to_i) if params[:position].present?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to leads_path, notice: "Lead moved to #{@lead.stage.to_s.humanize}." }
      end
    rescue => e
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append("flash", partial: "shared/error", locals: { message: e.message })
        end
        format.html { redirect_to leads_path, alert: "Failed to move lead: #{e.message}" }
      end
    end
  end

  def apply
    @lead = Lead.find(params[:id])
    @profile = @lead.profile

    result = Apply::Orchestrator.call(lead: @lead, profile: @profile)

    @apply_url = result[:response][:apply_url]

    if result[:success]
      @adapter        = result[:response][:adapter]
      @fields_result  = @adapter.extract_fields
      @payload_result = @adapter.build_payload
    else
      @fallback         = true
      @fallback_message = result[:response].dig(:error, :message) ||
                          "This ATS is not yet supported. Please apply manually."
    end

    @application = @lead.application || @lead.build_application(
      ats_type: @lead.ats_type || "unknown",
      status:   :draft
    )
    @application.apply_url    = @apply_url
    @application.form_payload = @payload_result&.dig(:response, :payload) || {}
    @application.save!

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def submit_application
    @lead        = Lead.find(params[:id])
    @application = @lead.application

    if @application
      @application.update!(status: :submitted, submitted_at: Time.current)
      @lead.update!(stage: :applied)
      redirect_to lead_path(@lead), notice: "Application marked as submitted. Good luck!"
    else
      redirect_to lead_path(@lead), alert: "No application draft found."
    end
  end

  def destroy
    @lead = Lead.find(params[:id])
    @lead.destroy
    redirect_to leads_path, notice: "Lead deleted."
  end
end
