class CreateApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :applications do |t|
      t.references :lead, null: false, foreign_key: true
      t.integer :status
      t.string :ats_type

      t.timestamps
    end
  end
end
