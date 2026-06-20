# frozen_string_literal: true

require "test_helper"

class LineItemTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
  end

  test "validates driver inclusion" do
    line_item = @project.line_items.build(
      quantity: 1,
      rate_cents: 100,
      total_cost_forecast_cents: 100,
      driver: "invalid"
    )

    assert_not line_item.valid?
    assert_includes line_item.errors[:driver], "is not included in the list"
  end

  test "effective_risk_setting prefers line item override over group default" do
    package = @project.category_values.create!(dimension: :package, name: "Civil")
    line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package",
      package_value: package
    )

    @project.driver_risk_settings.create!(
      driver_dimension: "package",
      category_value: package,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    )

    line_item.line_item_risk_settings.create!(
      driver_type: "price",
      source_accuracy_class: "class_c_concept",
      distribution_type: "lognormal",
      min_pct: -10,
      mode_pct: 0,
      max_pct: 15
    )

    assert_equal "class_c_concept", line_item.effective_risk_setting("price").source_accuracy_class
    assert line_item.risk_setting_overridden?("price")
  end

  test "effective_risk_setting falls back to group default" do
    package = @project.category_values.create!(dimension: :package, name: "Civil")
    line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package",
      package_value: package
    )

    @project.driver_risk_settings.create!(
      driver_dimension: "package",
      category_value: package,
      driver_type: "design",
      source_accuracy_class: "class_b_budget_estimate",
      distribution_type: "triangular",
      min_pct: -15,
      mode_pct: 0,
      max_pct: 25
    )

    assert_equal "class_b_budget_estimate", line_item.effective_risk_setting("design").source_accuracy_class
    assert_not line_item.risk_setting_overridden?("design")
  end

  test "base_cost_cents is rate times quantity rounded to cents" do
    line_item = @project.line_items.create!(
      quantity: 2.5,
      rate_cents: 100_00,
      total_cost_forecast_cents: 250_00,
      driver: "package"
    )

    assert_equal 250_00, line_item.base_cost_cents
  end

  test "cost_bounds_cents_for applies additive percentiles to base cost" do
    line_item = @project.line_items.build(
      quantity: 2,
      rate_cents: 100_00,
      total_cost_forecast_cents: 200_00,
      driver: "package"
    )

    bounds = line_item.cost_bounds_cents_for(min_pct: -20, max_pct: 30)

    assert_equal 160_00, bounds[:cost_min_cents]
    assert_equal 260_00, bounds[:cost_max_cents]
  end

  test "update_cost_bounds_from_percentiles! persists bounds" do
    line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package"
    )

    line_item.update_cost_bounds_from_percentiles!(min_pct: -10, max_pct: 15)
    line_item.reload

    assert_equal 90_00, line_item.cost_min_cents
    assert_equal 115_00, line_item.cost_max_cents
  end

  test "persists money amounts above 32-bit integer limit" do
    large_cents = 3_740_732_600

    line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: large_cents,
      total_cost_forecast_cents: large_cents,
      driver: "package"
    )

    line_item.reload
    assert_equal large_cents, line_item.rate_cents
    assert_equal large_cents, line_item.total_cost_forecast_cents
  end
end
