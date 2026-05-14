# frozen_string_literal: true

class CompaniesController < AuthenticatedController
  before_action :set_company, only: %i[show edit update destroy]

  def index
    @companies = Company.order(:name)
  end

  def show
  end

  def new
    @company = Company.new
  end

  def create
    @company = Company.new(company_params)
    if @company.save
      redirect_to @company, notice: "Company created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @company.update(company_params)
      redirect_to @company, notice: "Company updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy!
    redirect_to companies_path, notice: "Company removed."
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(
      :name, :address_line1, :address_line2, :city, :country_iso, :logo
    )
  end
end
