class CreateSearchQueries < ActiveRecord::Migration[8.1]
  def change
    create_table :search_queries do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :title
      t.string :portal
      t.string :additional_filters
      t.datetime :last_run_at
      t.integer :run_count, default: 0

      t.timestamps
    end

    add_index :search_queries, [:profile_id, :last_run_at]
  end
end
