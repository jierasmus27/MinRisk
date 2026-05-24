# frozen_string_literal: true

class Project < ApplicationRecord
  has_paper_trail
  belongs_to :company
  has_many :category_values, dependent: :destroy
  has_many :line_items, dependent: :destroy
  has_many :package_risk_drivers, dependent: :destroy
  has_many :spreadsheet_imports, dependent: :destroy
  has_one_attached :logo

  ESTIMATE_ACCURACY_CLASSES = %w[class_2 class_3 class_4].freeze

  validates :name, presence: true
  validates :currency_iso, presence: true
  validates :estimate_accuracy_class, inclusion: { in: ESTIMATE_ACCURACY_CLASSES }, allow_blank: true
  validate :currency_iso_known
  validate :time_zone_known
  validate :confidence_levels_shape
  validate :logo_content_type_and_size

  before_validation :normalize_currency_and_confidence_levels

  def import_summary
    {
      total_base_cost_cents: line_items.sum(:total_cost_forecast_cents),
      line_item_count: line_items.count,
      cost_package_count: cost_package_count
    }
  end

  def cost_package_count
    with_package = line_items.where.not(package_value_id: nil).distinct.count(:package_value_id)
    without_package = line_items.where(package_value_id: nil).exists? ? 1 : 0
    with_package + without_package
  end

  private

  def normalize_currency_and_confidence_levels
    self.currency_iso = currency_iso&.upcase&.strip
    self.confidence_levels ||= []
    self.confidence_levels = confidence_levels.reject(&:blank?).map(&:to_i).sort.uniq
  end

  def currency_iso_known
    return if currency_iso.blank?

    errors.add(:currency_iso, "is not a valid ISO 4217 code") unless Money::Currency.find(currency_iso)
  end

  def time_zone_known
    return if time_zone.blank?

    errors.add(:time_zone, "is not a valid Rails time zone") unless ActiveSupport::TimeZone[time_zone]
  end

  def confidence_levels_shape
    levels = confidence_levels
    if levels.blank?
      errors.add(:confidence_levels, "choose at least one percentile")
      return
    end

    levels.each do |n|
      unless n.is_a?(Integer) && n.in?(10..90) && (n % 10).zero?
        errors.add(:confidence_levels, "contains invalid percentile #{n.inspect}")
      end
    end
    errors.add(:confidence_levels, "must be unique") if levels.uniq.length != levels.length
  end

  def logo_content_type_and_size
    return unless logo.attached?

    allowed = %w[image/png image/jpeg image/webp]
    unless allowed.include?(logo.content_type)
      errors.add(:logo, "must be PNG, JPEG, or WebP")
      return
    end

    max_bytes = 5.megabytes
    errors.add(:logo, "must be #{max_bytes / 1.megabyte} MB or smaller") if logo.byte_size > max_bytes
  end
end
