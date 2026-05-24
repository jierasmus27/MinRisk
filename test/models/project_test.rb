# frozen_string_literal: true

require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @company = Company.create!(name: "Test Co", country_iso: "US")
    @project = @company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
  end

  test "import_summary returns zeros when no line items are committed" do
    summary = @project.import_summary

    assert_equal 0, summary[:total_base_cost_cents]
    assert_equal 0, summary[:line_item_count]
    assert_equal 0, summary[:cost_package_count]
  end

  test "import_summary aggregates committed line item totals" do
    package_a = @project.category_values.create!(dimension: :package, name: "Civil")
    package_b = @project.category_values.create!(dimension: :package, name: "MEP")

    @project.line_items.create!(quantity: 1, rate_cents: 100_00, total_cost_forecast_cents: 100_00, package_value: package_a)
    @project.line_items.create!(quantity: 2, rate_cents: 50_00, total_cost_forecast_cents: 100_00, package_value: package_a)
    @project.line_items.create!(quantity: 1, rate_cents: 75_00, total_cost_forecast_cents: 75_00, package_value: package_b)
    @project.line_items.create!(quantity: 1, rate_cents: 25_00, total_cost_forecast_cents: 25_00)

    summary = @project.import_summary

    assert_equal 300_00, summary[:total_base_cost_cents]
    assert_equal 4, summary[:line_item_count]
    assert_equal 3, summary[:cost_package_count]
  end
end
