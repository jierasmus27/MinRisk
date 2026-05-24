# frozen_string_literal: true

class SpreadsheetImportCommitJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(spreadsheet_import)
    @import = spreadsheet_import
    return if @import.committed?

    @import.commit!
  rescue SpreadsheetImportCommit::NotCommittable => e
    revert_commit!(e.message)
  rescue StandardError => e
    revert_commit!(e.message)
    raise
  end

  private

  def revert_commit!(message)
    @import.update!(status: "preview_ready", commit_error: message)
  end
end
