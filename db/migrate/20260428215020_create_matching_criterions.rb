class CreateMatchingCriterions < ActiveRecord::Migration[8.1]
  def change
    create_table :matching_criterions do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :required_keywords, array: true, default: []
      t.string :excluded_keywords, array: true, default: []
      t.integer :min_salary
      t.string :preferred_locations, array: true, default: []
      t.string :work_mode, default: "remote"
      t.integer :llm_threshold, default: 70

      t.timestamps
    end
  end
end
