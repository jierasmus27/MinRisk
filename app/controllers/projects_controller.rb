# frozen_string_literal: true

class ProjectsController < AuthenticatedController
  before_action :set_company
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = @company.projects.order(:name)
  end

  def show
    prepare_project_page
  end

  def new
    prepare_project_page
    @project = @company.projects.new(
      currency_iso: "USD",
      time_zone: "UTC",
      monte_carlo_iterations: 10_000,
      confidence_levels: [ 10, 50, 90 ]
    )
  end

  def create
    prepare_project_page
    @project = @company.projects.new(project_params)

    unless assign_company_from_selection!
      render :new, status: :unprocessable_entity
      return
    end

    if @project.save
      redirect_to company_project_path(@project.company, @project), notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to company_project_path(@company, @project)
  end

  def update
    if params[:remove_logo].present?
      @project.logo.purge
      redirect_to company_project_path(@company, @project), notice: "Logo removed."
      return
    end

    unless assign_company_from_selection!
      prepare_project_page
      render :show, status: :unprocessable_entity
      return
    end

    if @project.update(project_params)
      redirect_to company_project_path(@project.company, @project), notice: "Project updated."
    else
      prepare_project_page
      render :show, status: :unprocessable_entity
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

  def prepare_project_page
    @companies = Company.order(:name)
    @new_company ||= Company.new
    @company_selection = params[:company_selection].presence || @company.id.to_s
  end

  def assign_company_from_selection!
    selection = params[:company_selection]
    return true if selection.blank? || selection == @company.id.to_s

    if selection == "new"
      @new_company = Company.new(new_company_params)
      unless @new_company.save
        @company_selection = "new"
        return false
      end
      target_company = @new_company
    else
      target_company = Company.find_by(id: selection)
      unless target_company
        @company_selection = selection
        return false
      end
    end

    if @project.persisted?
      @project.update!(company: target_company)
    else
      @project.company = target_company
    end
    @company = target_company
    true
  end

  def new_company_params
    params.fetch(:new_company, {}).permit(:name, :address_line1, :address_line2, :city, :country_iso)
  end
end
