# frozen_string_literal: true

class RiskInputsController < AuthenticatedController
  before_action :set_company
  before_action :set_project

  def show
    @companies = Company.includes(:projects).order(:name)
    @filters = filter_params
    @package_rows = RiskInputs::PackageTreeQuery.new(project: @project, **@filters).call
    @driver_records_by_package = @project.package_risk_drivers.group_by(&:package_value_id)
    @wbs_options = @project.category_values.wbs.order(:name)
    @cost_type_options = @project.category_values.cost_type.order(:name)
    @driver_types = PackageRiskDriver::DRIVER_TYPES
    @driver_cards = @driver_types.index_with { |driver_type| default_driver_card(driver_type) }
    @summary = @project.import_summary
    @packages_with_drivers_count = @project.package_risk_drivers.distinct.count(:package_value_id)
    @total_package_count = @project.cost_package_count
    @selected_package_ids = selected_package_ids_from_params
  end

  def update
    apply_params = risk_input_params

    if apply_params[:package_value_ids].blank?
      redirect_to company_project_risk_inputs_path(@company, @project, preserved_filter_params), alert: "Select at least one package."
      return
    end

    applied_count = RiskInputs::ApplyDriver.new(
      project: @project,
      package_value_ids: apply_params[:package_value_ids],
      driver_type: apply_params[:driver_type],
      source_accuracy_class: apply_params[:source_accuracy_class],
      distribution_type: apply_params[:distribution_type],
      min_pct: apply_params[:min_pct],
      mode_pct: apply_params[:mode_pct],
      max_pct: apply_params[:max_pct]
    ).call

    redirect_to company_project_risk_inputs_path(
      @company,
      @project,
      preserved_filter_params.merge(selected: apply_params[:package_value_ids])
    ),
    notice: "Applied #{apply_params[:driver_type].humanize} settings to #{applied_count} package#{'s' unless applied_count == 1}."
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to company_project_risk_inputs_path(@company, @project, preserved_filter_params), alert: e.message
  end

  private

  def set_company
    @company = Company.find(params[:company_id])
  end

  def set_project
    @project = @company.projects.find(params[:project_id])
  end

  def filter_params
    {
      wbs_value_id: params[:wbs_value_id].presence,
      cost_type_value_id: params[:cost_type_value_id].presence,
      sort: params[:sort].presence || "name",
      direction: params[:direction].presence || "asc"
    }
  end

  def preserved_filter_params
    {}.tap do |hash|
      hash[:wbs_value_id] = params[:wbs_value_id] if params[:wbs_value_id].present?
      hash[:cost_type_value_id] = params[:cost_type_value_id] if params[:cost_type_value_id].present?
      hash[:sort] = params[:sort] if params[:sort].present?
      hash[:direction] = params[:direction] if params[:direction].present?
    end
  end

  def risk_input_params
    params.require(:risk_input).permit(
      :driver_type,
      :source_accuracy_class,
      :distribution_type,
      :min_pct,
      :mode_pct,
      :max_pct,
      package_value_ids: []
    )
  end

  def default_driver_card(driver_type)
    PackageRiskDriver.defaults_for(driver_type).merge(driver_type:)
  end

  def selected_package_ids_from_params
    Array(params[:selected]).filter_map do |id|
      next if id.blank?

      id.to_i
    end.uniq
  end
end
