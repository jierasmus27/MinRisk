# frozen_string_literal: true

require "test_helper"

class LineItemRiskSettingTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Project", currency_iso: "USD", confidence_levels: [ 50 ])
    @line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package"
    )
  end

  test "is valid with expected attributes" do
    record = LineItemRiskSetting.new(
      line_item: @line_item,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    )

    assert record.valid?
  end

  test "validates uniqueness per line item and driver type" do
    LineItemRiskSetting.create!(
      line_item: @line_item,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    )

    duplicate = LineItemRiskSetting.new(
      line_item: @line_item,
      driver_type: "price",
      source_accuracy_class: "class_c_concept",
      distribution_type: "lognormal",
      min_pct: -10,
      mode_pct: 0,
      max_pct: 20
    )

    refute duplicate.valid?
    assert_includes duplicate.errors[:driver_type], "has already been taken"
  end
end
