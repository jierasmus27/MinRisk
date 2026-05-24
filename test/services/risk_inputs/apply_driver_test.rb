# frozen_string_literal: true

require "test_helper"

module RiskInputs
  class ApplyDriverTest < ActiveSupport::TestCase
    setup do
      company = Company.create!(name: "Test Co", country_iso: "US")
      @project = company.projects.create!(name: "Project", currency_iso: "USD", confidence_levels: [ 50 ])
      @package_a = @project.category_values.create!(dimension: :package, name: "Alpha")
      @package_b = @project.category_values.create!(dimension: :package, name: "Beta")
    end

    test "creates records for each selected package" do
      count = ApplyDriver.new(
        project: @project,
        package_value_ids: [ @package_a.id, @package_b.id ],
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: -20,
        mode_pct: 0,
        max_pct: 30
      ).call

      assert_equal 2, count
      assert_equal 2, @project.package_risk_drivers.where(driver_type: "price").count
    end

    test "updates existing record on re-apply" do
      @project.package_risk_drivers.create!(
        package_value: @package_a,
        driver_type: "design",
        source_accuracy_class: "class_b_budget_estimate",
        distribution_type: "triangular",
        min_pct: -15,
        mode_pct: 0,
        max_pct: 25
      )

      ApplyDriver.new(
        project: @project,
        package_value_ids: [ @package_a.id ],
        driver_type: "design",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: -12,
        mode_pct: 0,
        max_pct: 18
      ).call

      record = @project.package_risk_drivers.find_by!(package_value: @package_a, driver_type: "design")
      assert_equal "class_c_concept", record.source_accuracy_class
      assert_equal "lognormal", record.distribution_type
      assert_equal BigDecimal("-12"), record.min_pct
    end
  end
end
