require "rails_helper"

RSpec.describe "Smoke test", type: :request do
  it "loads the Rails environment" do
    expect(Rails.env).to be_test
  end

  it "connects to the database" do
    expect { ActiveRecord::Base.connection.execute("SELECT 1") }.not_to raise_error
  end

  it "has FactoryBot configured" do
    expect(FactoryBot).to respond_to(:define)
  end
end
