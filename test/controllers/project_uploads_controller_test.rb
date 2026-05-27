# frozen_string_literal: true

require "test_helper"

class ProjectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(operator_id: "operator-1", password: "secret-key-12")
    post session_path, params: { operator_id: "operator-1", password: "secret-key-12" }

    @company = Company.create!(name: "Acme", country_iso: "US")
    @project_a = @company.projects.create!(name: "Alpha", currency_iso: "USD", confidence_levels: [ 50 ])
    @project_b = @company.projects.create!(name: "Beta", currency_iso: "USD", confidence_levels: [ 50 ])
  end

  test "show lists all company projects in the selector" do
    get company_project_upload_path(@company, @project_a)

    assert_response :success
    assert_select "#scope-project-select option[selected]", text: "Alpha"
    assert_select "#scope-project-select option", text: "Beta"
    assert_select "#scope-project-select option[value=?]",
      company_project_upload_path(@company, @project_b)
  end

  test "show renders import summary for committed project data" do
    import = @project_a.spreadsheet_imports.create!(status: "committed")
    package = @project_a.category_values.create!(dimension: :package, name: "Civil")
    @project_a.line_items.create!(
      project: @project_a,
      spreadsheet_import: import,
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package",
      package_value: package
    )

    get company_project_upload_path(@company, @project_a)

    assert_response :success
    assert_select "h3", text: "Import Summary"
    assert_select ".font-tabular-numeric", text: "$100.00"
    assert_select ".font-tabular-numeric", text: "1"
  end

  test "show does not enable commit polling without a committing import" do
    get company_project_upload_path(@company, @project_a)

    assert_response :success
    assert_select "[data-import-commit-polling-value='false']"
    assert_select "[data-import-commit-target='progress'].hidden"
  end

  test "show renders commit progress when import is committing" do
    @import = @project_a.spreadsheet_imports.create!(
      status: "committing",
      preview_payload: {
        "summary" => {
          "valid_row_count" => 1,
          "invalid_row_count" => 0,
          "line_item_count" => 1,
          "cost_package_count" => 1,
          "warning_count" => 0
        }
      }
    )

    get company_project_upload_path(@company, @project_a, import_id: @import.id)

    assert_response :success
    assert_select "[data-controller='import-commit'][data-import-commit-polling-value='true']"
    assert_select "[data-import-commit-target='progress']:not(.hidden)"
  end
end
