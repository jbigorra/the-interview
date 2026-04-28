class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.string :full_name, null: false
      t.string :email, null: false
      t.text :resume_text
      t.text :cover_letter_template
      t.jsonb :common_answers, default: {}
      t.jsonb :personal_info, default: {}

      t.timestamps
    end
  end
end
