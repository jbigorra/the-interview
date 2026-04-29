class FixLeadEventsSchema < ActiveRecord::Migration[8.1]
  def change
    # Change stage columns from string to integer to match Lead stage enum values
    remove_column :lead_events, :from_stage, :string
    remove_column :lead_events, :to_stage, :string

    add_column :lead_events, :from_stage, :integer
    add_column :lead_events, :to_stage, :integer, null: false

    # Add default for trigger and ensure not null
    change_column :lead_events, :trigger, :string, null: false, default: "manual"

    # Add composite index for timeline queries
    add_index :lead_events, [ :lead_id, :created_at ]
  end
end
