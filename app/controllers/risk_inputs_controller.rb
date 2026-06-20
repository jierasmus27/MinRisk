# frozen_string_literal: true

class RiskInputsController < AuthenticatedController
  before_action :set_company
  before_action :set_project

  def show
    @companies = Company.includes(:projects).order(:name)
    @filters = filter_params
    @driver_group_rows = RiskInputs::DriverGroupTreeQuery.new(project: @project, **@filters).call
    @wbs_options = @project.category_values.wbs.order(:name)
    @cost_type_options = @project.category_values.cost_type.order(:name)
    @driver_types = RiskDriverSettings::DRIVER_TYPES
    @driver_cards = @driver_types.index_with { |driver_type| default_driver_card(driver_type) }
    @summary = @project.import_summary
    @driver_groups_with_settings_count = @project.driver_groups_with_settings_count
    @total_driver_group_count = @project.driver_group_count
    @selected_group_keys = selected_group_keys_from_params
    @selected_line_item_ids = selected_line_item_ids_from_params
  end

  def update
    apply_params = risk_input_params

    if apply_params[:driver_group_keys].blank? && apply_params[:line_item_ids].blank?
      redirect_to company_project_risk_inputs_path(@company, @project, preserved_filter_params), alert: "Select at least one driver group or line item."
      return
    end

    result = RiskInputs::ApplyDriver.new(
      project: @project,
      driver_group_keys: apply_params[:driver_group_keys],
      line_item_ids: apply_params[:line_item_ids],
      driver_type: apply_params[:driver_type],
      source_accuracy_class: apply_params[:source_accuracy_class],
      distribution_type: apply_params[:distribution_type],
      min_pct: apply_params[:min_pct],
      mode_pct: apply_params[:mode_pct],
      max_pct: apply_params[:max_pct]
    ).call

    redirect_params = preserved_filter_params
    redirect_params[:selected_groups] = apply_params[:driver_group_keys] if apply_params[:driver_group_keys].present?
    redirect_params[:selected_line_items] = apply_params[:line_item_ids] if apply_params[:line_item_ids].present?

    redirect_to company_project_risk_inputs_path(@company, @project, redirect_params),
    notice: apply_notice(apply_params[:driver_type], result)
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
      driver_group_keys: [],
      line_item_ids: []
    )
  end

  def default_driver_card(driver_type)
    RiskDriverSettings.defaults_for(driver_type).merge(driver_type:)
  end

  def selected_group_keys_from_params
    Array(params[:selected_groups]).filter_map(&:presence).uniq
  end

  def selected_line_item_ids_from_params
    Array(params[:selected_line_items]).filter_map do |id|
      next if id.blank?

      id.to_i
    end.uniq
  end

  def apply_notice(driver_type, result)
    parts = []
    if result.groups_applied.positive?
      parts << "#{result.groups_applied} driver group#{'s' unless result.groups_applied == 1}"
    end
    if result.line_items_applied.positive?
      parts << "#{result.line_items_applied} line item#{'s' unless result.line_items_applied == 1}"
    end

    "Applied #{driver_type.humanize} settings to #{parts.join(' and ')}."
  end
end
