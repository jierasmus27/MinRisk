# frozen_string_literal: true

require "test_helper"

class RiskInputsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(operator_id: "operator-1", password: "secret-key-12")
    post session_path, params: { operator_id: "operator-1", password: "secret-key-12" }

    @company = Company.create!(name: "Acme", country_iso: "US")
    @project = @company.projects.create!(name: "Alpha", currency_iso: "USD", confidence_levels: [ 50 ])
    @other_project = @company.projects.create!(name: "Beta", currency_iso: "USD", confidence_levels: [ 50 ])

    @package = @project.category_values.create!(dimension: :package, name: "Civil")
    @wbs = @project.category_values.create!(dimension: :wbs, name: "WBS-1")
    @cost_type = @project.category_values.create!(dimension: :cost_type, name: "Direct")

    @project.line_items.create!(
      quantity: 1,
      rate_cents: 125_00,
      total_cost_forecast_cents: 125_00,
      driver: "package",
      package_value: @package,
      wbs_value: @wbs,
      cost_type_value: @cost_type
    )
  end

  test "show renders risk input screen" do
    get company_project_risk_inputs_path(@company, @project)

    assert_response :success
    assert_select "h1", text: "Risk Input Configuration"
    assert_select "h2", text: "Cost Packages / Line Items"
    assert_select "span", text: "Civil"
  end

  test "show lists all company projects in the selector" do
    get company_project_risk_inputs_path(@company, @project)

    assert_response :success
    assert_select "#risk-inputs-project-select option[selected]", text: "Alpha"
    assert_select "#risk-inputs-project-select option", text: "Beta"
    assert_select "#risk-inputs-project-select option[value=?]",
      company_project_risk_inputs_path(@company, @other_project)
  end

  test "update applies driver to selected package" do
    patch company_project_risk_inputs_path(@company, @project), params: {
      risk_input: {
        package_value_ids: [ @package.id ],
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: "-20",
        mode_pct: "0",
        max_pct: "30"
      }
    }

    assert_redirected_to company_project_risk_inputs_path(@company, @project, selected: [ @package.id ])
    assert_equal 1, @project.package_risk_drivers.where(package_value: @package, driver_type: "price").count

    follow_redirect!
    assert_select "input[type=checkbox][value='#{@package.id}'][checked]"
    assert_select "span", text: "Price"
  end

  test "show preserves selected packages from query params" do
    get company_project_risk_inputs_path(@company, @project, selected: [ @package.id ])

    assert_response :success
    assert_select "input[type=checkbox][value='#{@package.id}'][checked]"
  end
end
