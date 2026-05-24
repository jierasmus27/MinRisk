# frozen_string_literal: true

class PackageRiskDriver < ApplicationRecord
  DRIVER_TYPES = %w[price quantity design].freeze

  SOURCE_ACCURACY_CLASSES = {
    "class_b_budget_quote" => "Class B - Budget Quote",
    "class_c_concept" => "Class C - Concept",
    "class_b_budget_estimate" => "Class B - Budget Estimate"
  }.freeze

  DEFAULTS_BY_DRIVER_TYPE = {
    "price" => {
      source_accuracy_class: "class_b_budget_quote",
      distribution_type: "triangular",
      min_pct: -20,
      mode_pct: 0,
      max_pct: 30
    },
    "quantity" => {
      source_accuracy_class: "class_c_concept",
      distribution_type: "lognormal",
      min_pct: -25,
      mode_pct: 0,
      max_pct: 40
    },
    "design" => {
      source_accuracy_class: "class_b_budget_estimate",
      distribution_type: "triangular",
      min_pct: -15,
      mode_pct: 0,
      max_pct: 25
    }
  }.freeze

  belongs_to :project
  belongs_to :package_value, class_name: "CategoryValue"

  validates :driver_type, inclusion: { in: DRIVER_TYPES }
  validates :source_accuracy_class, inclusion: { in: SOURCE_ACCURACY_CLASSES.keys }
  validates :distribution_type, inclusion: { in: LineItem::DISTRIBUTION_TYPES }
  validates :min_pct, :mode_pct, :max_pct, presence: true, numericality: true
  validates :driver_type, uniqueness: { scope: :package_value_id }
  validate :package_dimension_is_package
  validate :package_in_same_project
  validate :ordered_percentiles

  def self.defaults_for(driver_type)
    DEFAULTS_BY_DRIVER_TYPE.fetch(driver_type)
  end

  private

  def package_dimension_is_package
    return if package_value.blank? || package_value.package?

    errors.add(:package_value, "must have package dimension")
  end

  def package_in_same_project
    return if project.blank? || package_value.blank? || package_value.project_id == project_id

    errors.add(:package_value, "must belong to the same project")
  end

  def ordered_percentiles
    return if min_pct.blank? || mode_pct.blank? || max_pct.blank?
    return if min_pct <= mode_pct && mode_pct <= max_pct

    errors.add(:base, "Min must be less than or equal to Most Likely, and Most Likely must be less than or equal to Max")
  end
end
