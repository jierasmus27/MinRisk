# frozen_string_literal: true

module RiskInputs
  class PackageTreeQuery
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
      package_rows = build_package_rows
      sort_rows(package_rows)
    end

    private

    attr_reader :project, :wbs_value_id, :cost_type_value_id, :sort, :direction

    def build_package_rows
      scope = filtered_scope.includes(:wbs_value, :cost_type_value)

      grouped_rows = scope.group_by(&:package_value_id)
      grouped_rows.map do |package_id, line_items|
        package_name = package_name_for(package_id)
        {
          package_value_id: package_id,
          name: package_name,
          amount_cents: line_items.sum(&:total_cost_forecast_cents),
          line_item_count: line_items.length,
          linked_drivers: linked_driver_types(package_id),
          line_items: build_line_items(line_items)
        }
      end
    end

    def filtered_scope
      scope = project.line_items
      scope = scope.where(wbs_value_id:) if wbs_value_id
      scope = scope.where(cost_type_value_id:) if cost_type_value_id
      scope
    end

    def package_name_for(package_id)
      return "Unassigned" if package_id.nil?

      package_names[package_id] || "Unknown package"
    end

    def package_names
      @package_names ||= project.category_values.package.pluck(:id, :name).to_h
    end

    def linked_driver_types(package_id)
      return [] if package_id.nil?

      drivers_by_package_id.fetch(package_id, [])
    end

    def drivers_by_package_id
      @drivers_by_package_id ||= project.package_risk_drivers.group_by(&:package_value_id).transform_values do |drivers|
        drivers.map(&:driver_type).sort
      end
    end

    def build_line_items(line_items)
      line_items.sort_by do |line_item|
        [
          line_item.wbs_value&.name.to_s,
          line_item.cost_type_value&.name.to_s,
          line_item.total_cost_forecast_cents
        ]
      end.map do |line_item|
        {
          id: line_item.id,
          wbs_name: line_item.wbs_value&.name.presence || "Unassigned",
          cost_type_name: line_item.cost_type_value&.name.presence || "Unassigned",
          amount_cents: line_item.total_cost_forecast_cents
        }
      end
    end

    def sort_rows(rows)
      sorted = rows.sort_by do |row|
        sort == "amount" ? row[:amount_cents] : row[:name].downcase
      end
      direction == "desc" ? sorted.reverse : sorted
    end

    def presence_to_i(value)
      return nil if value.blank?

      value.to_i
    end
  end
end
