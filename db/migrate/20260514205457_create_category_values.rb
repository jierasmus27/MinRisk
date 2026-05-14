class CreateCategoryValues < ActiveRecord::Migration[8.1]
  def change
    create_table :category_values do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :dimension, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :category_values, [ :project_id, :dimension, :name ], unique: true
  end
end
