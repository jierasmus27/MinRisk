# frozen_string_literal: true

module RiskInputs
  class ApplyDriver
    def initialize(project:, package_value_ids:, driver_type:, source_accuracy_class:, distribution_type:, min_pct:, mode_pct:, max_pct:)
      @project = project
      @package_value_ids = package_value_ids
      @driver_type = driver_type
      @source_accuracy_class = source_accuracy_class
      @distribution_type = distribution_type
      @min_pct = min_pct
      @mode_pct = mode_pct
      @max_pct = max_pct
    end

    def call
      package_ids = normalize_package_ids
      return 0 if package_ids.empty?

      packages = project.category_values.package.where(id: package_ids).index_by(&:id)
      missing_ids = package_ids - packages.keys
      raise ArgumentError, "Unknown package ids: #{missing_ids.join(', ')}" if missing_ids.any?

      PackageRiskDriver.transaction do
        package_ids.each do |package_id|
          record = project.package_risk_drivers.find_or_initialize_by(
            package_value_id: package_id,
            driver_type: driver_type
          )
          record.assign_attributes(
            source_accuracy_class: source_accuracy_class,
            distribution_type: distribution_type,
            min_pct: min_pct,
            mode_pct: mode_pct,
            max_pct: max_pct
          )
          record.save!
        end
      end

      package_ids.count
    end

    private

    attr_reader :project, :package_value_ids, :driver_type, :source_accuracy_class, :distribution_type, :min_pct, :mode_pct, :max_pct

    def normalize_package_ids
      Array(package_value_ids).filter_map do |value|
        next if value.blank?

        value.to_i
      end.uniq
    end
  end
end
