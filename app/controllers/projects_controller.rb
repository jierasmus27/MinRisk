# frozen_string_literal: true

class ProjectsController < AuthenticatedController
  before_action :set_company
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = @company.projects.order(:name)
  end

  def show
    prepare_show_page
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
    redirect_to company_project_path(@company, @project)
  end

  def update
    if params[:remove_logo].present?
      @project.logo.purge
      redirect_to company_project_path(@company, @project), notice: "Logo removed."
      return
    end

    unless apply_company_selection!
      prepare_show_page
      render :show, status: :unprocessable_entity
      return
    end

    if @project.update(project_params)
      redirect_to company_project_path(@project.company, @project), notice: "Project updated."
    else
      prepare_show_page
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

  def prepare_show_page
    @companies = Company.order(:name)
    @new_company ||= Company.new
    @company_selection = params[:company_selection].presence || @company.id.to_s
  end

  def apply_company_selection!
    selection = params[:company_selection]
    return true if selection.blank? || selection == @company.id.to_s

    if selection == "new"
      @new_company = Company.new(new_company_params)
      unless @new_company.save
        @company_selection = "new"
        return false
      end
      @project.update!(company: @new_company)
      @company = @new_company
    else
      selected = Company.find_by(id: selection)
      unless selected
        @company_selection = selection
        return false
      end

      @project.update!(company: selected)
      @company = selected
    end
    true
  end

  def new_company_params
    params.fetch(:new_company, {}).permit(:name, :address_line1, :address_line2, :city, :country_iso)
  end
end
