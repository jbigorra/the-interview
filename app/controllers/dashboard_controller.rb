# typed: false
class DashboardController < ApplicationController
  def show
    @profile = Profile.first_or_create!(
      full_name: "Your Name",
      email: "you@example.com"
    )
    @search_queries = @profile.search_queries.order(created_at: :desc)
    @leads_by_stage = Lead.group(:stage).count
    @recent_leads = @profile.leads.order(created_at: :desc).limit(10)
  end
end
