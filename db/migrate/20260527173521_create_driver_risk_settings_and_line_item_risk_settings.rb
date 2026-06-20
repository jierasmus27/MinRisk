# frozen_string_literal: true

class CreateDriverRiskSettingsAndLineItemRiskSettings < ActiveRecord::Migration[8.1]
  def up
    create_table :driver_risk_settings do |t|
      t.references :project, null: false, foreign_key: true
      t.string :driver_dimension, null: false
      t.references :category_value, null: true, foreign_key: true
      t.string :driver_type, null: false
      t.string :source_accuracy_class, null: false
      t.string :distribution_type, null: false
      t.decimal :min_pct, precision: 8, scale: 3, null: false
      t.decimal :mode_pct, precision: 8, scale: 3, null: false
      t.decimal :max_pct, precision: 8, scale: 3, null: false

      t.timestamps
    end

    add_index :driver_risk_settings,
              [ :project_id, :driver_dimension, :category_value_id, :driver_type ],
              unique: true,
              name: "index_driver_risk_settings_on_project_group_and_type"

    create_table :line_item_risk_settings do |t|
      t.references :line_item, null: false, foreign_key: true
      t.string :driver_type, null: false
      t.string :source_accuracy_class, null: false
      t.string :distribution_type, null: false
      t.decimal :min_pct, precision: 8, scale: 3, null: false
      t.decimal :mode_pct, precision: 8, scale: 3, null: false
      t.decimal :max_pct, precision: 8, scale: 3, null: false

      t.timestamps
    end

    add_index :line_item_risk_settings, [ :line_item_id, :driver_type ], unique: true

    execute <<~SQL.squish
      INSERT INTO driver_risk_settings (
        project_id,
        driver_dimension,
        category_value_id,
        driver_type,
        source_accuracy_class,
        distribution_type,
        min_pct,
        mode_pct,
        max_pct,
        created_at,
        updated_at
      )
      SELECT
        project_id,
        'package',
        package_value_id,
        driver_type,
        source_accuracy_class,
        distribution_type,
        min_pct,
        mode_pct,
        max_pct,
        created_at,
        updated_at
      FROM package_risk_drivers
    SQL

    drop_table :package_risk_drivers
  end

  def down
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

    execute <<~SQL.squish
      INSERT INTO package_risk_drivers (
        project_id,
        package_value_id,
        driver_type,
        source_accuracy_class,
        distribution_type,
        min_pct,
        mode_pct,
        max_pct,
        created_at,
        updated_at
      )
      SELECT
        project_id,
        category_value_id,
        driver_type,
        source_accuracy_class,
        distribution_type,
        min_pct,
        mode_pct,
        max_pct,
        created_at,
        updated_at
      FROM driver_risk_settings
      WHERE driver_dimension = 'package'
    SQL

    drop_table :line_item_risk_settings
    drop_table :driver_risk_settings
  end
end
