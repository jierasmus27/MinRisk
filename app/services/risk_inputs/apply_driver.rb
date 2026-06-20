# frozen_string_literal: true

module RiskInputs
  class ApplyDriver
    Result = Struct.new(:groups_applied, :line_items_applied, keyword_init: true)

    def initialize(project:, driver_group_keys:, line_item_ids:, driver_type:, source_accuracy_class:, distribution_type:, min_pct:, mode_pct:, max_pct:)
      @project = project
      @driver_group_keys = driver_group_keys
      @line_item_ids = line_item_ids
      @driver_type = driver_type
      @source_accuracy_class = source_accuracy_class
      @distribution_type = distribution_type
      @min_pct = min_pct
      @mode_pct = mode_pct
      @max_pct = max_pct
    end

    def call
      groups = normalize_group_keys
      item_ids = normalize_line_item_ids
      return Result.new(groups_applied: 0, line_items_applied: 0) if groups.empty? && item_ids.empty?

      groups_applied = 0
      line_items_applied = 0

      affected_line_item_ids = Set.new

      ApplicationRecord.transaction do
        groups_applied = apply_to_groups(groups, affected_line_item_ids) if groups.any?
        line_items_applied = apply_to_line_items(item_ids, affected_line_item_ids) if item_ids.any?
        refresh_cost_bounds!(affected_line_item_ids)
      end

      Result.new(groups_applied:, line_items_applied:)
    end

    private

    attr_reader :project, :driver_group_keys, :line_item_ids, :driver_type, :source_accuracy_class,
                :distribution_type, :min_pct, :mode_pct, :max_pct

    def apply_to_groups(groups, affected_line_item_ids)
      groups.each do |driver_dimension, category_value_id|
        validate_group!(driver_dimension, category_value_id)

        record = project.driver_risk_settings.find_or_initialize_by(
          driver_dimension: driver_dimension,
          category_value_id: category_value_id,
          driver_type: driver_type
        )
        record.assign_attributes(setting_attributes)
        record.save!

        clear_line_item_overrides_for_group(driver_dimension, category_value_id)
        line_items_for_group(driver_dimension, category_value_id).pluck(:id).each do |line_item_id|
          affected_line_item_ids << line_item_id
        end
      end

      groups.size
    end

    def apply_to_line_items(item_ids, affected_line_item_ids)
      line_items = project.line_items.where(id: item_ids).index_by(&:id)
      missing_ids = item_ids - line_items.keys
      raise ArgumentError, "Unknown line item ids: #{missing_ids.join(', ')}" if missing_ids.any?

      item_ids.each do |line_item_id|
        record = line_items.fetch(line_item_id).line_item_risk_settings.find_or_initialize_by(driver_type: driver_type)
        record.assign_attributes(setting_attributes)
        record.save!
        affected_line_item_ids << line_item_id
      end

      item_ids.size
    end

    def refresh_cost_bounds!(affected_line_item_ids)
      return if affected_line_item_ids.empty?

      project.line_items.where(id: affected_line_item_ids.to_a).find_each do |line_item|
        line_item.update_cost_bounds_from_percentiles!(min_pct: min_pct, max_pct: max_pct)
      end
    end

    def clear_line_item_overrides_for_group(driver_dimension, category_value_id)
      scope = line_items_for_group(driver_dimension, category_value_id)
      LineItemRiskSetting.where(line_item_id: scope.select(:id), driver_type: driver_type).delete_all
    end

    def line_items_for_group(driver_dimension, category_value_id)
      scope = project.line_items.where(driver: driver_dimension)
      case driver_dimension
      when "package"
        category_value_id.nil? ? scope.where(package_value_id: nil) : scope.where(package_value_id: category_value_id)
      when "wbs"
        category_value_id.nil? ? scope.where(wbs_value_id: nil) : scope.where(wbs_value_id: category_value_id)
      when "discipline"
        category_value_id.nil? ? scope.where(discipline_value_id: nil) : scope.where(discipline_value_id: category_value_id)
      else
        scope.none
      end
    end

    def validate_group!(driver_dimension, category_value_id)
      unless LineItem::DRIVERS.include?(driver_dimension)
        raise ArgumentError, "Unknown driver dimension: #{driver_dimension}"
      end

      return if category_value_id.nil?

      category = project.category_values.find_by(id: category_value_id)
      raise ArgumentError, "Unknown category value id: #{category_value_id}" if category.blank?
      raise ArgumentError, "Category value #{category_value_id} is not a #{driver_dimension}" unless category.dimension == driver_dimension
    end

    def setting_attributes
      {
        source_accuracy_class: source_accuracy_class,
        distribution_type: distribution_type,
        min_pct: min_pct,
        mode_pct: mode_pct,
        max_pct: max_pct
      }
    end

    def normalize_group_keys
      Array(driver_group_keys).filter_map do |key|
        next if key.blank?

        parse_group_key(key)
      end.uniq
    end

    def parse_group_key(key)
      driver_dimension, category_part = key.to_s.split(":", 2)
      raise ArgumentError, "Invalid driver group key: #{key}" if driver_dimension.blank? || category_part.blank?

      category_value_id = category_part == "unassigned" ? nil : Integer(category_part)
      [ driver_dimension, category_value_id ]
    rescue ArgumentError
      raise
    rescue StandardError
      raise ArgumentError, "Invalid driver group key: #{key}"
    end

    def normalize_line_item_ids
      Array(line_item_ids).filter_map do |value|
        next if value.blank?

        value.to_i
      end.uniq
    end
  end
end
