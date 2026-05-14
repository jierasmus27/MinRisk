# frozen_string_literal: true

class ProjectsController < AuthenticatedController
  before_action :set_company
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = @company.projects.order(:name)
  end

  def show
  end

  def new
    @project = @company.projects.new(
      currency_iso: "USD",
      time_zone: "UTC",
      monte_carlo_iterations: 10_000,
      confidence_levels: [ 10, 50, 90 ]
    )
  end

  def create
    @project = @company.projects.new(project_params)
    if @project.save
      redirect_to company_project_upload_path(@company, @project), notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to [ @company, @project ], notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to company_projects_path(@company), notice: "Project removed."
  end

  private

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_project
    @project = @company.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(
      :name, :code, :description, :currency_iso, :time_zone,
      :start_date, :target_end_date, :monte_carlo_iterations,
      :estimate_accuracy_class, :base_year, :logo,
      confidence_levels: []
    )
  end
end
