class CreateLeads < ActiveRecord::Migration[8.1]
  def change
    create_table :leads do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :title
      t.string :company
      t.string :location
      t.string :url, null: false
      t.string :ats_type
      t.text :description
      t.text :raw_payload, comment: "Original JSON from discovery source"
      t.string :fingerprint, null: false
      t.integer :stage, default: 0, null: false
      t.integer :match_score
      t.string :match_recommendation
      t.text :match_reasoning
      t.datetime :evaluated_at
      t.integer :stage_position, default: 0

      t.timestamps
    end

    add_index :leads, :fingerprint, unique: true
    add_index :leads, [ :profile_id, :stage, :stage_position ]
    add_index :leads, [ :profile_id, :stage, :match_score ],
              name: "idx_leads_for_board_sort"
  end
end
