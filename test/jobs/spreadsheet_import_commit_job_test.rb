# frozen_string_literal: true

require "test_helper"

class SpreadsheetImportCommitJobTest < ActiveJob::TestCase
  setup do
    company = Company.create!(name: "Test Co", country_iso: "US")
    @project = company.projects.create!(name: "Test Project", currency_iso: "USD", confidence_levels: [ 50 ])
    @import = SpreadsheetImport.create!(project: @project, status: "committing")
    @import.file.attach(
      io: StringIO.new(SpreadsheetImportTemplate.to_binary),
      filename: "import.xlsx",
      content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    @import.parse!
    @import.update!(status: "committing", commit_error: nil)
  end

  test "commits valid preview rows" do
    assert_difference -> { @project.line_items.count }, +3 do
      SpreadsheetImportCommitJob.perform_now(@import)
    end

    assert @import.reload.committed?
    assert_nil @import.commit_error
  end

  test "reverts to preview_ready when commit is not allowed" do
    @import.update!(
      status: "committing",
      preview_payload: @import.preview_payload.merge(
        "summary" => @import.preview_summary.merge(
          "valid_row_count" => 0,
          "invalid_row_count" => 3
        )
      )
    )

    assert_no_difference -> { @project.line_items.count } do
      SpreadsheetImportCommitJob.perform_now(@import)
    end

    assert @import.reload.preview_ready?
    assert_match(/not ready to commit/, @import.commit_error)
  end
end
