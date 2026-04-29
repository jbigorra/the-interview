class AddMissingColumnsToApplications < ActiveRecord::Migration[8.1]
  def change
    # Rename status integer to a string enum column with default
    remove_column :applications, :status, :integer
    add_column :applications, :status, :string, null: false, default: "draft"

    # Ensure ats_type is not null
    change_column_null :applications, :ats_type, false

    # Add missing jsonb payload columns
    add_column :applications, :form_payload, :jsonb, null: false, default: {}
    add_column :applications, :ats_response, :jsonb, null: false, default: {}

    # ATS integration fields
    add_column :applications, :external_id, :string
    add_column :applications, :apply_url, :string
    add_column :applications, :submitted_at, :datetime
  end
end
