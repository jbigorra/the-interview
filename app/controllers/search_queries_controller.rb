# typed: false

class SearchQueriesController < ApplicationController
  before_action :set_profile
  before_action :set_search_query, only: %i[edit update destroy run]

  def new
    @search_query = @profile.search_queries.new
  end

  def create
    @search_query = @profile.search_queries.new(search_query_params)
    if @search_query.save
      redirect_to root_path, notice: "Search query created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @search_query.update(search_query_params)
      redirect_to root_path, notice: "Search query updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @search_query.destroy
    redirect_to root_path, notice: "Search query deleted."
  end

  def run
    if @search_query.recently_run?
      redirect_to root_path, alert: "This query was recently run. Please wait before running again."
      return
    end

    DiscoveryJob.perform_later(@search_query)
    redirect_to root_path, notice: "Discovery job enqueued for #{@search_query.title}."
  end

  private

  def set_profile
    @profile = Profile.first_or_create!(
      full_name: "Your Name",
      email: "you@example.com"
    )
  end

  def set_search_query
    @search_query = @profile.search_queries.find(params[:id])
  end

  def search_query_params
    params.require(:search_query).permit(:title, :portal, :additional_filters)
  end
end
