# frozen_string_literal: true

require "test_helper"

class PackageRiskDriverTest < ActiveSupport::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Project", currency_iso: "USD", confidence_levels: [ 50 ])
    @other_project = company.projects.create!(name: "Project 2", currency_iso: "USD", confidence_levels: [ 50 ])
    @package = @project.category_values.create!(dimension: :package, name: "Civil")
  end

  test "is valid with expected attributes" do
    record = PackageRiskDriver.new(
      project: @project,
      package_value: @package,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    )

    assert record.valid?
  end

  test "validates uniqueness per package and driver type" do
    PackageRiskDriver.create!(
      project: @project,
      package_value: @package,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    )

    duplicate = PackageRiskDriver.new(
      project: @project,
      package_value: @package,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -15,
      mode_pct: 0,
      max_pct: 25
    )

    refute duplicate.valid?
    assert_includes duplicate.errors[:driver_type], "has already been taken"
  end

  test "requires ordered percentiles" do
    record = PackageRiskDriver.new(
      project: @project,
      package_value: @package,
      driver_type: "quantity",
      source_accuracy_class: "class_c_concept",
      distribution_type: "lognormal",
      min_pct: 10,
      mode_pct: 0,
      max_pct: 20
    )

    refute record.valid?
    assert_includes record.errors[:base].join, "Min must be less than or equal"
  end

  test "requires package to belong to the same project" do
    other_package = @other_project.category_values.create!(dimension: :package, name: "MEP")
    record = PackageRiskDriver.new(
      project: @project,
      package_value: other_package,
      driver_type: "design",
      source_accuracy_class: "class_b_budget_estimate",
      distribution_type: "triangular",
      min_pct: -10,
      mode_pct: 0,
      max_pct: 15
    )

    refute record.valid?
    assert_includes record.errors[:package_value], "must belong to the same project"
  end
end
