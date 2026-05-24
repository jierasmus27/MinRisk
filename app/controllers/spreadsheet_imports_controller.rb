# frozen_string_literal: true

class SpreadsheetImportsController < AuthenticatedController
  before_action :set_company
  before_action :set_project
  before_action :set_import

  def commit
    unless @import.commitable?
      redirect_to company_project_upload_path(@company, @project, import_id: @import.id),
                  alert: "This import cannot be committed. Fix validation issues or upload a file first."
      return
    end

    if @import.committed?
      redirect_to company_project_upload_path(@company, @project),
                  notice: "This import was already committed."
      return
    end

    @import.commit!
    count = @import.line_items.count
    label = @import.file.attached? ? @import.file.filename.to_s : "import"

    redirect_to company_project_upload_path(@company, @project),
                notice: "Committed #{label}: #{count} line item#{'s' unless count == 1} added to the project."
  rescue SpreadsheetImportCommit::NotCommittable
    redirect_to company_project_upload_path(@company, @project, import_id: @import.id),
                alert: "This import cannot be committed."
  end

  def destroy
    label = @import.file.attached? ? @import.file.filename.to_s : "import"
    line_count = @import.line_items.count
    was_preview = !@import.committed?

    @import.destroy!

    notice = if line_count.positive?
      "Removed #{label} and #{line_count} line item#{'s' unless line_count == 1}."
    elsif was_preview
      "Removed preview for #{label}."
    else
      "Removed #{label}."
    end

    redirect_to company_project_upload_path(@company, @project), notice: notice
  end

  private

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_project
    @project = @company.projects.find(params[:project_id])
  end

  def set_import
    @import = @project.spreadsheet_imports.find(params[:id])
  end
end
