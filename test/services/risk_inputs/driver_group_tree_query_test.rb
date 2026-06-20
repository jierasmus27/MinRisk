# frozen_string_literal: true

require "test_helper"

module RiskInputs
  class DriverGroupTreeQueryTest < ActiveSupport::TestCase
    setup do
      company = Company.create!(name: "Test Co", country_iso: "US")
      @project = company.projects.create!(name: "Project", currency_iso: "USD", confidence_levels: [ 50 ])

      @package_a = @project.category_values.create!(dimension: :package, name: "Alpha")
      @package_b = @project.category_values.create!(dimension: :package, name: "Beta")
      @wbs_a = @project.category_values.create!(dimension: :wbs, name: "WBS-A")
      @wbs_b = @project.category_values.create!(dimension: :wbs, name: "WBS-B")
      @type_direct = @project.category_values.create!(dimension: :cost_type, name: "Direct")
      @type_indirect = @project.category_values.create!(dimension: :cost_type, name: "Indirect")

      @project.line_items.create!(quantity: 1, rate_cents: 100_00, total_cost_forecast_cents: 100_00, driver: "package", package_value: @package_a, wbs_value: @wbs_a, cost_type_value: @type_direct)
      @project.line_items.create!(quantity: 1, rate_cents: 200_00, total_cost_forecast_cents: 200_00, driver: "package", package_value: @package_a, wbs_value: @wbs_b, cost_type_value: @type_indirect)
      @project.line_items.create!(quantity: 1, rate_cents: 50_00, total_cost_forecast_cents: 50_00, driver: "package", package_value: @package_b, wbs_value: @wbs_b, cost_type_value: @type_direct)
      @line_wbs = @project.line_items.create!(quantity: 1, rate_cents: 75_00, total_cost_forecast_cents: 75_00, driver: "wbs", package_value: @package_b, wbs_value: @wbs_a, cost_type_value: @type_direct)

      @project.driver_risk_settings.create!(
        driver_dimension: "package",
        category_value: @package_a,
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: -20,
        mode_pct: 0,
        max_pct: 30
      )
    end

    test "aggregates driver group totals and linked drivers" do
      rows = DriverGroupTreeQuery.new(project: @project).call

      alpha = rows.find { |row| row[:name] == "Alpha" && row[:driver_dimension] == "package" }
      assert_equal 300_00, alpha[:amount_cents]
      assert_equal 2, alpha[:line_item_count]
      assert_equal [ "price" ], alpha[:linked_drivers]
      assert_equal "package:#{@package_a.id}", alpha[:group_key]
    end

    test "includes wbs-driven groups separately from package groups" do
      rows = DriverGroupTreeQuery.new(project: @project).call

      wbs_group = rows.find { |row| row[:driver_dimension] == "wbs" && row[:name] == "WBS-A" }
      assert_equal 75_00, wbs_group[:amount_cents]
      assert_equal 1, wbs_group[:line_item_count]
    end

    test "filters by wbs and sorts by amount descending" do
      rows = DriverGroupTreeQuery.new(
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

    test "line item row reflects override state" do
      @line_wbs.line_item_risk_settings.create!(
        driver_type: "quantity",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: -10,
        mode_pct: 0,
        max_pct: 20
      )

      rows = DriverGroupTreeQuery.new(project: @project).call
      wbs_group = rows.find { |row| row[:group_key] == "wbs:#{@wbs_a.id}" }
      line_row = wbs_group[:line_items].find { |row| row[:id] == @line_wbs.id }

      assert line_row[:overridden]["quantity"]
      assert_includes line_row[:linked_drivers], "quantity"
    end
  end
end
