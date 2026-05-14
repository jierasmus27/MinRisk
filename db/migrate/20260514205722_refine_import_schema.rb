# frozen_string_literal: true

class RefineImportSchema < ActiveRecord::Migration[8.1]
  def change
    change_column_null :category_values, :dimension, false
    change_column_null :category_values, :name, false
    add_index :category_values, [ :project_id, :dimension, :name ], unique: true

    change_column_default :projects, :monte_carlo_iterations, from: nil, to: 10_000
    change_column_null :projects, :monte_carlo_iterations, false
    change_column_default :projects, :confidence_levels, from: nil, to: []
    change_column_null :projects, :confidence_levels, false

    change_column_default :spreadsheet_imports, :status, from: nil, to: "pending"
    change_column_null :spreadsheet_imports, :status, false

    change_column_null :line_items, :spreadsheet_import_id, true
    change_column_null :line_items, :quantity, false
    change_column_null :line_items, :total_cost_forecast_cents, false
    change_column_null :line_items, :rate_cents, false
    change_column :line_items, :quantity, :decimal, precision: 24, scale: 8

    add_reference :line_items, :cost_type_value, foreign_key: { to_table: :category_values }, null: true
    add_reference :line_items, :package_value, foreign_key: { to_table: :category_values }, null: true
    add_reference :line_items, :wbs_value, foreign_key: { to_table: :category_values }, null: true
    add_reference :line_items, :discipline_value, foreign_key: { to_table: :category_values }, null: true

    add_index :line_items, [ :project_id, :spreadsheet_import_id ]
  end
end
