# frozen_string_literal: true

class DriverRiskSetting < ApplicationRecord
  include RiskDriverSettings

  belongs_to :project
  belongs_to :category_value

  validates :driver_dimension, inclusion: { in: LineItem::DRIVERS }
  validates :driver_type, uniqueness: { scope: [ :project_id, :driver_dimension, :category_value_id ] }
  validate :category_dimension_matches_driver, if: -> { category_value.present? }
  validate :category_in_same_project, if: -> { category_value.present? }

  def self.group_key_for(driver_dimension:, category_value_id:)
    "#{driver_dimension}:#{category_value_id || 'unassigned'}"
  end

  def group_key
    self.class.group_key_for(driver_dimension:, category_value_id:)
  end

  private

  def category_dimension_matches_driver
    return if category_value.blank? || driver_dimension.blank?
    return if category_value.dimension == driver_dimension

    errors.add(:category_value, "must have #{driver_dimension} dimension")
  end

  def category_in_same_project
    return if project.blank? || category_value.blank? || category_value.project_id == project_id

    errors.add(:category_value, "must belong to the same project")
  end
end
