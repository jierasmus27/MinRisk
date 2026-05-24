# frozen_string_literal: true

class ProjectUploadsController < AuthenticatedController
  before_action :set_company
  before_action :set_project

  def show
    @companies = Company.includes(:projects).order(:name)
    @imports = @project.spreadsheet_imports.includes(:line_items).with_attached_file.order(created_at: :desc).limit(10)
    @preview_import = load_preview_import
    @preview = @preview_import&.preview_payload
  end

  def template
    send_data SpreadsheetImportTemplate.to_binary,
              filename: SpreadsheetImportTemplate::FILENAME,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  def create
    unless params[:file].present?
      redirect_to company_project_upload_path(@company, @project), alert: "Choose a file to upload."
      return
    end

    import = @project.spreadsheet_imports.build(status: "pending")
    import.file.attach(params[:file])
    if import.save
      import.parse!
      notice = import.commitable? ? "File parsed. Review the summary below, then commit when ready." : "File uploaded but parsing found issues. Review validation feedback."
      redirect_to company_project_upload_path(@company, @project, import_id: import.id), notice: notice
    else
      redirect_to company_project_upload_path(@company, @project), alert: import.errors.full_messages.to_sentence
    end
  end

  private

  def load_preview_import
    scope = @project.spreadsheet_imports.where(status: %w[preview_ready committing failed])
    if params[:import_id].present?
      scope.find_by(id: params[:import_id]) || scope.order(created_at: :desc).first
    else
      scope.order(created_at: :desc).first
    end
  end

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_project
    @project = @company.projects.find(params[:project_id])
  end
end
