class CreatePackageRiskDrivers < ActiveRecord::Migration[8.1]
  def change
    create_table :package_risk_drivers do |t|
      t.references :project, null: false, foreign_key: true
      t.references :package_value, null: false, foreign_key: { to_table: :category_values }
      t.string :driver_type, null: false
      t.string :source_accuracy_class, null: false
      t.string :distribution_type, null: false
      t.decimal :min_pct, precision: 8, scale: 3, null: false
      t.decimal :mode_pct, precision: 8, scale: 3, null: false
      t.decimal :max_pct, precision: 8, scale: 3, null: false

      t.timestamps
    end

    add_index :package_risk_drivers, [ :package_value_id, :driver_type ], unique: true
  end
end
