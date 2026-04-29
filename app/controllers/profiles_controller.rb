# typed: false

class ProfilesController < ApplicationController
  def show
    @profile = Profile.first_or_create!(full_name: "Your Name", email: "you@example.com")
    @criterion = @profile.matching_criterion || @profile.build_matching_criterion
  end

  def update
    @profile = Profile.first_or_create!(full_name: "Your Name", email: "you@example.com")
    normalize_array_fields!

    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      @criterion = @profile.matching_criterion || @profile.build_matching_criterion
      render :show, status: :unprocessable_entity
    end
  end

  private

  def normalize_array_fields!
    mc = params.dig(:profile, :matching_criterion_attributes)
    return unless mc

    %w[required_keywords excluded_keywords preferred_locations].each do |field|
      next unless mc[field].present?

      mc[field] = mc[field].split(",").map(&:strip).reject(&:blank?)
    end
  end

  def profile_params
    params.require(:profile).permit(
      :full_name, :email, :resume_text, :cover_letter_template,
      :common_answers, :personal_info,
      matching_criterion_attributes: [
        :id, :min_salary, :work_mode, :llm_threshold,
        required_keywords: [], excluded_keywords: [], preferred_locations: []
      ]
    )
  end
end
