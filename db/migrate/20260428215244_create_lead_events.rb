class CreateLeadEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :lead_events do |t|
      t.references :lead, null: false, foreign_key: true
      t.string :from_stage
      t.string :to_stage
      t.string :trigger

      t.timestamps
    end
  end
end
