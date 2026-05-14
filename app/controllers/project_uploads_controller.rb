# frozen_string_literal: true

class ProjectUploadsController < AuthenticatedController
  before_action :set_company
  before_action :set_project

  def show
    @imports = @project.spreadsheet_imports.order(created_at: :desc).limit(10)
  end

  def create
    unless params[:file].present?
      redirect_to company_project_upload_path(@company, @project), alert: "Choose a file to upload."
      return
    end

    import = @project.spreadsheet_imports.build(status: "pending")
    import.file.attach(params[:file])
    if import.save
      redirect_to company_project_upload_path(@company, @project), notice: "File received. Parsing will run in a follow-up step."
    else
      redirect_to company_project_upload_path(@company, @project), alert: import.errors.full_messages.to_sentence
    end
  end

  private

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_project
    @project = @company.projects.find(params[:project_id])
  end
end
