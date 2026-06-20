# frozen_string_literal: true

require "test_helper"

module RiskInputs
  class ApplyDriverTest < ActiveSupport::TestCase
    setup do
      company = Company.create!(name: "Test Co", country_iso: "US")
      @project = company.projects.create!(name: "Project", currency_iso: "USD", confidence_levels: [ 50 ])
      @package_a = @project.category_values.create!(dimension: :package, name: "Alpha")
      @package_b = @project.category_values.create!(dimension: :package, name: "Beta")
      @wbs = @project.category_values.create!(dimension: :wbs, name: "WBS-1")

      @line_a = @project.line_items.create!(
        quantity: 1,
        rate_cents: 100_00,
        total_cost_forecast_cents: 100_00,
        driver: "package",
        package_value: @package_a,
        wbs_value: @wbs
      )
      @line_b = @project.line_items.create!(
        quantity: 1,
        rate_cents: 50_00,
        total_cost_forecast_cents: 50_00,
        driver: "package",
        package_value: @package_b,
        wbs_value: @wbs
      )
    end

    test "creates group records for each selected driver group" do
      result = ApplyDriver.new(
        project: @project,
        driver_group_keys: [ "package:#{@package_a.id}", "package:#{@package_b.id}" ],
        line_item_ids: [],
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: -20,
        mode_pct: 0,
        max_pct: 30
      ).call

      assert_equal 2, result.groups_applied
      assert_equal 0, result.line_items_applied
      assert_equal 2, @project.driver_risk_settings.where(driver_type: "price").count
    end

    test "updates existing group record on re-apply" do
      @project.driver_risk_settings.create!(
        driver_dimension: "package",
        category_value: @package_a,
        driver_type: "design",
        source_accuracy_class: "class_b_budget_estimate",
        distribution_type: "triangular",
        min_pct: -15,
        mode_pct: 0,
        max_pct: 25
      )

      ApplyDriver.new(
        project: @project,
        driver_group_keys: [ "package:#{@package_a.id}" ],
        line_item_ids: [],
        driver_type: "design",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: -12,
        mode_pct: 0,
        max_pct: 18
      ).call

      record = @project.driver_risk_settings.find_by!(category_value: @package_a, driver_type: "design")
      assert_equal "class_c_concept", record.source_accuracy_class
      assert_equal "lognormal", record.distribution_type
      assert_equal BigDecimal("-12"), record.min_pct
    end

    test "group apply clears line item overrides for that accuracy type" do
      @line_a.line_item_risk_settings.create!(
        driver_type: "price",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: -5,
        mode_pct: 0,
        max_pct: 10
      )

      ApplyDriver.new(
        project: @project,
        driver_group_keys: [ "package:#{@package_a.id}" ],
        line_item_ids: [],
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: -20,
        mode_pct: 0,
        max_pct: 30
      ).call

      assert_not @line_a.line_item_risk_settings.exists?(driver_type: "price")
    end

    test "group apply recalculates cost bounds for all line items in group" do
      ApplyDriver.new(
        project: @project,
        driver_group_keys: [ "package:#{@package_a.id}" ],
        line_item_ids: [],
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: -20,
        mode_pct: 0,
        max_pct: 30
      ).call

      @line_a.reload
      @line_b.reload

      assert_equal 80_00, @line_a.cost_min_cents
      assert_equal 130_00, @line_a.cost_max_cents
      assert_nil @line_b.cost_min_cents
      assert_nil @line_b.cost_max_cents
    end

    test "line item apply recalculates cost bounds for selected items only" do
      ApplyDriver.new(
        project: @project,
        driver_group_keys: [],
        line_item_ids: [ @line_a.id ],
        driver_type: "quantity",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: -25,
        mode_pct: 0,
        max_pct: 40
      ).call

      @line_a.reload
      @line_b.reload

      assert_equal 75_00, @line_a.cost_min_cents
      assert_equal 140_00, @line_a.cost_max_cents
      assert_nil @line_b.cost_min_cents
      assert_nil @line_b.cost_max_cents
    end

    test "creates line item overrides for selected line items" do
      result = ApplyDriver.new(
        project: @project,
        driver_group_keys: [],
        line_item_ids: [ @line_a.id ],
        driver_type: "quantity",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: -25,
        mode_pct: 0,
        max_pct: 40
      ).call

      assert_equal 0, result.groups_applied
      assert_equal 1, result.line_items_applied
      assert_equal "class_c_concept", @line_a.line_item_risk_settings.find_by!(driver_type: "quantity").source_accuracy_class
    end
  end
end
