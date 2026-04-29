class AddMissingColumnsToNotes < ActiveRecord::Migration[8.1]
  def change
    # Rename content to body (task spec uses body)
    rename_column :notes, :content, :body
    change_column_null :notes, :body, false

    add_column :notes, :author, :string, null: false, default: "system"
  end
end
