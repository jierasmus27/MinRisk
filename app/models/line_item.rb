# frozen_string_literal: true

class LineItem < ApplicationRecord
  belongs_to :project
  belongs_to :spreadsheet_import, optional: true
  belongs_to :cost_type_value, class_name: "CategoryValue", optional: true
  belongs_to :package_value, class_name: "CategoryValue", optional: true
  belongs_to :wbs_value, class_name: "CategoryValue", optional: true
  belongs_to :discipline_value, class_name: "CategoryValue", optional: true

  has_many :line_item_risk_settings, dependent: :destroy

  # Money amounts can exceed 32-bit integer cents; force 64-bit casting even if
  # the schema cache was loaded before the widen_line_item_money_columns migration.
  attribute :rate_cents, :big_integer
  attribute :total_cost_forecast_cents, :big_integer
  attribute :cost_min_cents, :big_integer
  attribute :cost_max_cents, :big_integer

  monetize :total_cost_forecast_cents, with_model_currency: :currency_iso
  monetize :rate_cents, with_model_currency: :currency_iso
  monetize :cost_min_cents, allow_nil: true, with_model_currency: :currency_iso
  monetize :cost_max_cents, allow_nil: true, with_model_currency: :currency_iso

  DISTRIBUTION_TYPES = %w[triangular uniform normal lognormal].freeze
  DRIVERS = %w[package wbs discipline].freeze

  validates :quantity, presence: true
  validates :driver, presence: true, inclusion: { in: DRIVERS }
  validates :total_cost_forecast, presence: true
  validates :rate, presence: true
  validates :cost_distribution, inclusion: { in: DISTRIBUTION_TYPES }, allow_blank: true

  before_validation :normalize_cost_distribution
  before_validation :normalize_driver

  def currency_iso
    project.currency_iso
  end

  def driver_category_value
    case driver
    when "package" then package_value
    when "wbs" then wbs_value
    when "discipline" then discipline_value
    end
  end

  def driver_category_value_id
    driver_category_value&.id
  end

  def driver_group_key
    DriverRiskSetting.group_key_for(driver_dimension: driver, category_value_id: driver_category_value_id)
  end

  def effective_risk_setting(driver_type)
    line_item_risk_settings.find_by(driver_type:) ||
      project.driver_risk_settings.find_by(
        driver_dimension: driver,
        category_value_id: driver_category_value_id,
        driver_type:
      )
  end

  def risk_setting_overridden?(driver_type)
    line_item_risk_settings.exists?(driver_type:)
  end

  def base_cost_cents
    (BigDecimal(rate_cents.to_s) * quantity).round
  end

  def cost_bounds_cents_for(min_pct:, max_pct:)
    base = base_cost_cents
    {
      cost_min_cents: apply_cost_percentile(base, min_pct),
      cost_max_cents: apply_cost_percentile(base, max_pct)
    }
  end

  def update_cost_bounds_from_percentiles!(min_pct:, max_pct:)
    assign_attributes(cost_bounds_cents_for(min_pct:, max_pct:))
    save!
  end

  private

  def apply_cost_percentile(base_cents, pct)
    factor = BigDecimal("1") + (BigDecimal(pct.to_s) / 100)
    (BigDecimal(base_cents.to_s) * factor).round.to_i
  end

  def normalize_cost_distribution
    self.cost_distribution = cost_distribution&.strip&.downcase.presence
  end

  def normalize_driver
    normalized = driver&.strip&.downcase.presence
    normalized = "package" if normalized == "packages"
    self.driver = normalized
  end
end
