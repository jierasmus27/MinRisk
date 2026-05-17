# frozen_string_literal: true

class LineItem < ApplicationRecord
  has_paper_trail
  belongs_to :project
  belongs_to :spreadsheet_import, optional: true
  belongs_to :cost_type_value, class_name: "CategoryValue", optional: true
  belongs_to :package_value, class_name: "CategoryValue", optional: true
  belongs_to :wbs_value, class_name: "CategoryValue", optional: true
  belongs_to :discipline_value, class_name: "CategoryValue", optional: true

  monetize :total_cost_forecast_cents, with_model_currency: :currency_iso
  monetize :rate_cents, with_model_currency: :currency_iso
  monetize :cost_min_cents, allow_nil: true, with_model_currency: :currency_iso
  monetize :cost_max_cents, allow_nil: true, with_model_currency: :currency_iso

  DISTRIBUTION_TYPES = %w[triangular uniform normal lognormal].freeze

  validates :quantity, presence: true
  validates :total_cost_forecast, presence: true
  validates :rate, presence: true
  validates :cost_distribution, inclusion: { in: DISTRIBUTION_TYPES }, allow_blank: true

  before_validation :normalize_cost_distribution

  def currency_iso
    project.currency_iso
  end

  private

  def normalize_cost_distribution
    self.cost_distribution = cost_distribution&.strip&.downcase.presence
  end
end
