# frozen_string_literal: true

class WidenLineItemMoneyColumns < ActiveRecord::Migration[8.1]
  def change
    change_column :line_items, :rate_cents, :bigint, null: false
    change_column :line_items, :total_cost_forecast_cents, :bigint, null: false
    change_column :line_items, :cost_min_cents, :bigint
    change_column :line_items, :cost_max_cents, :bigint
  end
end
