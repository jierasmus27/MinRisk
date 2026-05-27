# frozen_string_literal: true

require "test_helper"

class SpreadsheetImportsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(operator_id: "operator-1", password: "secret-key-12")
    post session_path, params: { operator_id: "operator-1", password: "secret-key-12" }

    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
    @import = SpreadsheetImport.create!(project: @project, status: "preview_ready")
    @import.file.attach(
      io: StringIO.new(SpreadsheetImportTemplate.to_binary),
      filename: "import.xlsx",
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    @import.parse!
  end

  test "commit enqueues job and persists valid preview rows" do
    assert_enqueued_with(job: SpreadsheetImportCommitJob) do
      post commit_company_project_upload_import_path(@project.company, @project, @import)
    end

    assert_redirected_to company_project_upload_path(@project.company, @project, import_id: @import.id)
    assert @import.reload.committing?

    perform_enqueued_jobs

    assert @import.reload.committed?
    assert_equal 3, @import.line_items.count
  end

  test "commit rejects import with no valid rows" do
    @import.update!(
      preview_payload: @import.preview_payload.merge(
        "summary" => @import.preview_summary.merge(
          "valid_row_count" => 0,
          "invalid_row_count" => 3
        )
      )
    )

    assert_no_enqueued_jobs only: SpreadsheetImportCommitJob do
      post commit_company_project_upload_import_path(@project.company, @project, @import)
    end

    assert_redirected_to company_project_upload_path(@project.company, @project, import_id: @import.id)
    assert_match(/cannot be committed/, flash[:alert])
  end

  test "commit_status reports committing and committed states" do
    @import.update!(status: "committing")

    get commit_status_company_project_upload_import_path(@project.company, @project, @import)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "committing", body["status"]
    refute body["finished"]

    @import.update!(status: "committed")
    @import.line_items.create!(
      project: @project,
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package"
    )

    get commit_status_company_project_upload_import_path(@project.company, @project, @import)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "committed", body["status"]
    assert body["finished"]
    assert_match(/Committed import\.xlsx: 1 line item added/, body["message"])
  end

  test "destroy removes preview import" do
    assert_difference -> { @project.spreadsheet_imports.count }, -1 do
      delete company_project_upload_import_path(@project.company, @project, @import)
    end

    assert_redirected_to company_project_upload_path(@project.company, @project)
    assert_match(/Removed preview/, flash[:notice])
    assert_nil SpreadsheetImport.find_by(id: @import.id)
  end

  test "destroy rejects import while commit is in progress" do
    @import.update!(status: "committing")

    assert_no_difference -> { @project.spreadsheet_imports.count } do
      delete company_project_upload_import_path(@project.company, @project, @import)
    end

    assert_redirected_to company_project_upload_path(@project.company, @project, import_id: @import.id)
    assert_match(/still being committed/, flash[:alert])
  end

  test "destroy removes import and associated line items" do
    @import.update!(status: "committed")
    line = @project.line_items.create!(
      spreadsheet_import: @import,
      quantity: 1,
      rate_cents: 100_00,
      total_cost_forecast_cents: 100_00,
      driver: "package"
    )

    assert_difference [ -> { @project.spreadsheet_imports.count }, -> { @project.line_items.count } ], -1 do
      delete company_project_upload_import_path(@project.company, @project, @import)
    end

    assert_match(/1 line item/, flash[:notice])
    assert_nil LineItem.find_by(id: line.id)
  end
end
