# frozen_string_literal: true

module RiskInputs
  class DriverGroupTreeQuery
    SORT_KEYS = %w[name amount].freeze
    DIRECTIONS = %w[asc desc].freeze

    def initialize(project:, wbs_value_id: nil, cost_type_value_id: nil, sort: "name", direction: "asc")
      @project = project
      @wbs_value_id = presence_to_i(wbs_value_id)
      @cost_type_value_id = presence_to_i(cost_type_value_id)
      @sort = SORT_KEYS.include?(sort) ? sort : "name"
      @direction = DIRECTIONS.include?(direction) ? direction : "asc"
    end

    def call
      sort_rows(build_group_rows)
    end

    private

    attr_reader :project, :wbs_value_id, :cost_type_value_id, :sort, :direction

    def build_group_rows
      scope = filtered_scope.includes(:wbs_value, :cost_type_value, :package_value, :discipline_value, :line_item_risk_settings)

      scope.group_by { |line_item| group_key_for(line_item) }.map do |group_key, line_items|
        sample = line_items.first
        driver_dimension = sample.driver
        category_value_id = sample.driver_category_value_id
        category_value = sample.driver_category_value

        {
          group_key: group_key,
          driver_dimension: driver_dimension,
          category_value_id: category_value_id,
          name: category_name_for(category_value),
          amount_cents: line_items.sum(&:total_cost_forecast_cents),
          line_item_count: line_items.length,
          linked_drivers: linked_driver_types_for_group(driver_dimension, category_value_id, line_items),
          risk_settings_by_type: risk_settings_hash(group_settings_for(driver_dimension, category_value_id)),
          line_items: build_line_items(line_items, driver_dimension, category_value_id)
        }
      end
    end

    def filtered_scope
      scope = project.line_items
      scope = scope.where(wbs_value_id:) if wbs_value_id
      scope = scope.where(cost_type_value_id:) if cost_type_value_id
      scope
    end

    def group_key_for(line_item)
      DriverRiskSetting.group_key_for(
        driver_dimension: line_item.driver,
        category_value_id: line_item.driver_category_value_id
      )
    end

    def category_name_for(category_value)
      category_value&.name.presence || "Unassigned"
    end

    def group_settings_for(driver_dimension, category_value_id)
      group_settings_index[[ driver_dimension, category_value_id ]]
    end

    def group_settings_index
      @group_settings_index ||= project.driver_risk_settings.group_by do |setting|
        [ setting.driver_dimension, setting.category_value_id ]
      end
    end

    def line_item_settings_index
      @line_item_settings_index ||= LineItemRiskSetting
        .where(line_item_id: filtered_scope.select(:id))
        .group_by(&:line_item_id)
    end

    def linked_driver_types_for_group(driver_dimension, category_value_id, line_items)
      types = Set.new
      group_settings_for(driver_dimension, category_value_id)&.each { |setting| types << setting.driver_type }

      line_items.each do |line_item|
        line_item_settings_index.fetch(line_item.id, []).each { |setting| types << setting.driver_type }
      end

      types.to_a.sort
    end

    def build_line_items(line_items, driver_dimension, category_value_id)
      group_settings = group_settings_for(driver_dimension, category_value_id)

      line_items.sort_by do |line_item|
        [
          line_item.wbs_value&.name.to_s,
          line_item.cost_type_value&.name.to_s,
          line_item.total_cost_forecast_cents
        ]
      end.map do |line_item|
        overrides = line_item_settings_index.fetch(line_item.id, [])
        overridden = RiskDriverSettings::DRIVER_TYPES.index_with do |driver_type|
          overrides.any? { |setting| setting.driver_type == driver_type }
        end

        {
          id: line_item.id,
          label: line_item_label(line_item),
          amount_cents: line_item.total_cost_forecast_cents,
          linked_drivers: effective_linked_driver_types(line_item, overrides, group_settings),
          risk_settings_by_type: effective_settings_hash(line_item, overrides, group_settings),
          overridden: overridden
        }
      end
    end

    def line_item_label(line_item)
      parts = [
        "WBS: #{line_item.wbs_value&.name.presence || 'Unassigned'}",
        "Cost Type: #{line_item.cost_type_value&.name.presence || 'Unassigned'}"
      ]
      parts.join(" · ")
    end

    def effective_linked_driver_types(line_item, overrides, group_settings)
      types = Set.new
      group_settings&.each { |setting| types << setting.driver_type }
      overrides.each { |setting| types << setting.driver_type }
      types.to_a.sort
    end

    def effective_settings_hash(line_item, overrides, group_settings)
      RiskDriverSettings::DRIVER_TYPES.index_with do |driver_type|
        override = overrides.find { |setting| setting.driver_type == driver_type }
        setting = override || group_settings&.find { |record| record.driver_type == driver_type }
        serialize_setting(setting)
      end.compact
    end

    def risk_settings_hash(settings)
      return {} if settings.blank?

      settings.index_by(&:driver_type).transform_values { |setting| serialize_setting(setting) }
    end

    def serialize_setting(setting)
      return nil if setting.blank?

      {
        source_accuracy_class: setting.source_accuracy_class,
        distribution_type: setting.distribution_type,
        min_pct: setting.min_pct,
        mode_pct: setting.mode_pct,
        max_pct: setting.max_pct
      }
    end

    def sort_rows(rows)
      sorted = rows.sort_by do |row|
        sort_key = sort == "amount" ? row[:amount_cents] : row[:name].downcase
        [ sort_key, row[:driver_dimension], row[:group_key] ]
      end
      direction == "desc" ? sorted.reverse : sorted
    end

    def presence_to_i(value)
      return nil if value.blank?

      value.to_i
    end
  end
end
