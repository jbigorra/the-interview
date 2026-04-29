class AddUniqueIndexToApplicationsLeadId < ActiveRecord::Migration[8.1]
  def up
    remove_index :applications, column: :lead_id
    add_index :applications, :lead_id, unique: true
  end

  def down
    remove_index :applications, column: :lead_id
    add_index :applications, :lead_id
  end
end
