# frozen_string_literal: true

require "test_helper"

module RiskInputs
  class PackageTreeQueryTest < ActiveSupport::TestCase
    setup do
      company = Company.create!(name: "Test Co", country_iso: "US")
      @project = company.projects.create!(name: "Project", currency_iso: "USD", confidence_levels: [ 50 ])

      @package_a = @project.category_values.create!(dimension: :package, name: "Alpha")
      @package_b = @project.category_values.create!(dimension: :package, name: "Beta")
      @wbs_a = @project.category_values.create!(dimension: :wbs, name: "WBS-A")
      @wbs_b = @project.category_values.create!(dimension: :wbs, name: "WBS-B")
      @type_direct = @project.category_values.create!(dimension: :cost_type, name: "Direct")
      @type_indirect = @project.category_values.create!(dimension: :cost_type, name: "Indirect")

      @project.line_items.create!(quantity: 1, rate_cents: 100_00, total_cost_forecast_cents: 100_00, package_value: @package_a, wbs_value: @wbs_a, cost_type_value: @type_direct)
      @project.line_items.create!(quantity: 1, rate_cents: 200_00, total_cost_forecast_cents: 200_00, package_value: @package_a, wbs_value: @wbs_b, cost_type_value: @type_indirect)
      @project.line_items.create!(quantity: 1, rate_cents: 50_00, total_cost_forecast_cents: 50_00, package_value: @package_b, wbs_value: @wbs_b, cost_type_value: @type_direct)

      @project.package_risk_drivers.create!(
        package_value: @package_a,
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: -20,
        mode_pct: 0,
        max_pct: 30
      )
    end

    test "aggregates package totals and linked drivers" do
      rows = PackageTreeQuery.new(project: @project).call

      alpha = rows.find { |row| row[:name] == "Alpha" }
      assert_equal 300_00, alpha[:amount_cents]
      assert_equal 2, alpha[:line_item_count]
      assert_equal [ "price" ], alpha[:linked_drivers]
    end

    test "filters by wbs and sorts by amount descending" do
      rows = PackageTreeQuery.new(
        project: @project,
        wbs_value_id: @wbs_b.id,
        sort: "amount",
        direction: "desc"
      ).call

      assert_equal 2, rows.length
      assert_equal "Alpha", rows.first[:name]
      assert_equal 200_00, rows.first[:amount_cents]
      assert_equal "Beta", rows.second[:name]
      assert_equal 50_00, rows.second[:amount_cents]
    end
  end
end
