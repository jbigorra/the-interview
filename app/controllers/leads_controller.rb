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

  def destroy
    @lead = Lead.find(params[:id])
    @lead.destroy
    redirect_to leads_path, notice: "Lead deleted."
  end
end
