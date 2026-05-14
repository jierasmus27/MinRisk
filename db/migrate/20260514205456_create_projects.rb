class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name
      t.string :code
      t.text :description
      t.string :currency_iso
      t.string :time_zone
      t.date :start_date
      t.date :target_end_date
      t.integer :monte_carlo_iterations, null: false, default: 10_000
      t.jsonb :confidence_levels, null: false, default: []
      t.string :estimate_accuracy_class
      t.integer :base_year

      t.timestamps
    end
  end
end
