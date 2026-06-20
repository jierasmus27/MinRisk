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

    @line_item = @project.line_items.create!(
      quantity: 1,
      rate_cents: 125_00,
      total_cost_forecast_cents: 125_00,
      driver: "package",
      package_value: @package,
      wbs_value: @wbs,
      cost_type_value: @cost_type
    )
    @group_key = "package:#{@package.id}"
  end

  test "show renders risk input screen" do
    get company_project_risk_inputs_path(@company, @project)

    assert_response :success
    assert_select "h1", text: "Risk Input Configuration"
    assert_select "h2", text: "Driver Groups / Line Items"
    assert_select "span", text: "Civil"
  end

  test "show displays accuracy driver values in per-driver columns" do
    @project.driver_risk_settings.create!(
      driver_dimension: "package",
      category_value: @package,
      driver_type: "price",
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    )

    get company_project_risk_inputs_path(@company, @project)

    assert_response :success
    assert_select "th span", text: "Price"
    assert_select "th span", text: "Quantity"
    assert_select "th span", text: "Design"
    assert_select "td", text: /Class B/
    assert_select "td", text: /Budget Quote/
    assert_select "td", text: /Triangular/
    assert_select "td", text: /Likely/
    assert_select "td", text: /-20%/
    assert_select "td", text: /30%/
  end

  test "show lists all company projects in the selector" do
    get company_project_risk_inputs_path(@company, @project)

    assert_response :success
    assert_select "#risk-inputs-project-select option[selected]", text: "Alpha"
    assert_select "#risk-inputs-project-select option", text: "Beta"
    assert_select "#risk-inputs-project-select option[value=?]",
      company_project_risk_inputs_path(@company, @other_project)
  end

  test "update applies driver to selected driver group" do
    patch company_project_risk_inputs_path(@company, @project), params: {
      risk_input: {
        driver_group_keys: [ @group_key ],
        line_item_ids: [],
        driver_type: "price",
        source_accuracy_class: "class_b_budget_quote",
        distribution_type: "triangular",
        min_pct: "-20",
        mode_pct: "0",
        max_pct: "30"
      }
    }

    assert_redirected_to company_project_risk_inputs_path(@company, @project, selected_groups: [ @group_key ])
    assert_equal 1, @project.driver_risk_settings.where(category_value: @package, driver_type: "price").count

    follow_redirect!
    assert_select "input[type=checkbox][value=?][checked]", @group_key
    assert_select ".font-bold.uppercase", text: "Price"
  end

  test "update applies driver to selected line item" do
    patch company_project_risk_inputs_path(@company, @project), params: {
      risk_input: {
        driver_group_keys: [],
        line_item_ids: [ @line_item.id ],
        driver_type: "quantity",
        source_accuracy_class: "class_c_concept",
        distribution_type: "lognormal",
        min_pct: "-25",
        mode_pct: "0",
        max_pct: "40"
      }
    }

    assert_redirected_to company_project_risk_inputs_path(
      @company,
      @project,
      selected_line_items: [ @line_item.id ]
    )
    assert @line_item.line_item_risk_settings.exists?(driver_type: "quantity")
  end

  test "show preserves selected groups and line items from query params" do
    get company_project_risk_inputs_path(
      @company,
      @project,
      selected_groups: [ @group_key ],
      selected_line_items: [ @line_item.id ]
    )

    assert_response :success
    assert_select "input[type=checkbox][value=?][checked]", @group_key
    assert_select "input[type=checkbox][value=?][checked]", @line_item.id.to_s
  end
end
