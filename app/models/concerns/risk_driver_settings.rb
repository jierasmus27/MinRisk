# frozen_string_literal: true

module RiskDriverSettings
  extend ActiveSupport::Concern

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

  included do
    validates :driver_type, inclusion: { in: DRIVER_TYPES }
    validates :source_accuracy_class, inclusion: { in: SOURCE_ACCURACY_CLASSES.keys }
    validates :distribution_type, inclusion: { in: LineItem::DISTRIBUTION_TYPES }
    validates :min_pct, :mode_pct, :max_pct, presence: true, numericality: true
    validate :ordered_percentiles
  end

  class_methods do
    def defaults_for(driver_type)
      DEFAULTS_BY_DRIVER_TYPE.fetch(driver_type)
    end
  end

  def self.defaults_for(driver_type)
    DEFAULTS_BY_DRIVER_TYPE.fetch(driver_type)
  end

  def settings_attributes
    {
      source_accuracy_class: source_accuracy_class,
      distribution_type: distribution_type,
      min_pct: min_pct,
      mode_pct: mode_pct,
      max_pct: max_pct
    }
  end

  private

  def ordered_percentiles
    return if min_pct.blank? || mode_pct.blank? || max_pct.blank?
    return if min_pct <= mode_pct && mode_pct <= max_pct

    errors.add(:base, "Min must be less than or equal to Most Likely, and Most Likely must be less than or equal to Max")
  end
end
