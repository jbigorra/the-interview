# typed: false

class NotesController < ApplicationController
  def create
    @lead = Lead.find(params[:lead_id])
    @note = @lead.notes.new(note_params)
    @note.author = "user"

    if @note.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lead_path(@lead), notice: "Note added." }
      end
    else
      render turbo_stream: turbo_stream.replace("new_note", partial: "notes/form", locals: { note: @note, lead: @lead })
    end
  end

  private

  def note_params
    params.require(:note).permit(:body)
  end
end
