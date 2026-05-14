class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :project, null: false, foreign_key: true
      t.references :spreadsheet_import, null: true, foreign_key: true
      t.decimal :quantity, precision: 24, scale: 8, null: false
      t.integer :total_cost_forecast_cents, null: false
      t.integer :rate_cents, null: false
      t.integer :cost_min_cents
      t.integer :cost_max_cents
      t.string :cost_distribution
      t.references :cost_type_value, null: true, foreign_key: { to_table: :category_values }
      t.references :package_value, null: true, foreign_key: { to_table: :category_values }
      t.references :wbs_value, null: true, foreign_key: { to_table: :category_values }
      t.references :discipline_value, null: true, foreign_key: { to_table: :category_values }

      t.timestamps
    end

    add_index :line_items, [ :project_id, :spreadsheet_import_id ]
  end
end
